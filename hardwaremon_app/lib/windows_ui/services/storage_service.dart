import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/backend_config.dart';
import '../models/storage_models.dart';

class StorageService {
  Future<StorageSnapshot> fetchSnapshot() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/storage'))
        .timeout(const Duration(seconds: 14));
    _ensureSuccess(response, 'Storage telemetry');
    return StorageSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<StorageHistory> fetchHistory({
    String? driveId,
    int rangeSeconds = 3600,
    int points = 360,
  }) async {
    final query = <String, String>{
      'range_seconds': '$rangeSeconds',
      'points': '$points',
      'drive_id': ?driveId,
    };
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/storage/history',
    ).replace(queryParameters: query);
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Storage history');
    return StorageHistory.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<String> startScan(String driveId) async {
    final response = await _post('/storage/scan', {
      'drive_id': driveId,
    }, timeout: const Duration(seconds: 16));
    return response['job_id']?.toString() ?? '';
  }

  Future<StorageScanJob> fetchScan(String jobId) async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/storage/scan/$jobId'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Storage scan');
    return StorageScanJob.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<String> startBenchmark(String driveId, String mode) async {
    final response = await _post('/storage/benchmark', {
      'drive_id': driveId,
      'mode': mode,
    });
    return response['job_id']?.toString() ?? '';
  }

  Future<StorageBenchmarkJob> fetchBenchmark(String jobId) async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/storage/benchmark/$jobId'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Storage benchmark');
    return StorageBenchmarkJob.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<void> openDrive(String driveId) async {
    await _post('/storage/open', {'drive_id': driveId});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final response = await http
        .post(
          Uri.parse('${BackendConfig.baseUrl}$path'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    _ensureSuccess(response, path);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = '$operation failed (${response.statusCode})';
    try {
      final payload = jsonDecode(response.body) as Map;
      detail = payload['detail']?.toString() ?? detail;
    } catch (_) {}
    throw StateError(detail);
  }
}
