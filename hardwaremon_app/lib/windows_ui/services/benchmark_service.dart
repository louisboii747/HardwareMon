import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/backend_config.dart';
import '../models/benchmark_models.dart';

class BenchmarkService {
  Future<BenchmarkStatus> start() async {
    final response = await http
        .post(Uri.parse('${BackendConfig.baseUrl}/benchmark/start'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Start benchmark');
    return BenchmarkStatus.fromJson(_decodeMap(response.body));
  }

  Future<BenchmarkStatus> fetchStatus() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/benchmark/status'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Benchmark status');
    return BenchmarkStatus.fromJson(_decodeMap(response.body));
  }

  Future<BenchmarkResult?> fetchLatest() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/benchmark/latest'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return null;
    _ensureSuccess(response, 'Latest benchmark result');
    return BenchmarkResult.fromJson(_decodeMap(response.body));
  }

  Future<List<BenchmarkResult>> fetchResults({int limit = 20}) async {
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/benchmark/results',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Benchmark history');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => BenchmarkResult.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<BenchmarkStatus> cancel() async {
    final response = await http
        .post(Uri.parse('${BackendConfig.baseUrl}/benchmark/cancel'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Cancel benchmark');
    return BenchmarkStatus.fromJson(_decodeMap(response.body));
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException(
        'The benchmark service returned invalid data.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = '$operation failed (${response.statusCode})';
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['detail'] != null) {
        detail = payload['detail'].toString();
      }
    } catch (_) {}
    throw StateError(detail);
  }
}
