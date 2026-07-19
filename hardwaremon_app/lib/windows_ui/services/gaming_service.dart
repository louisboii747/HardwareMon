import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/backend_config.dart';
import '../models/gaming_models.dart';

class GamingService {
  Future<GamingCurrent> fetchCurrent() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/gaming/current'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Gaming status');
    return GamingCurrent.fromJson(_decodeMap(response.body));
  }

  Future<List<GamingSession>> fetchHistory({int limit = 50}) async {
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/gaming/history',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Gaming history');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => GamingSession.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<GamingSession?> fetchLatest() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/gaming/latest'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return null;
    _ensureSuccess(response, 'Latest gaming session');
    return GamingSession.fromJson(_decodeMap(response.body));
  }

  Future<GamingSession> fetchSession(String id) async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/gaming/session/$id'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Gaming session');
    return GamingSession.fromJson(_decodeMap(response.body));
  }

  Future<GamingStatistics> fetchStatistics() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/gaming/statistics'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Gaming statistics');
    return GamingStatistics.fromJson(_decodeMap(response.body));
  }

  Future<List<GameMetadata>> fetchCatalog() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/gaming/catalog'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Game catalog');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => GameMetadata.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> deleteSession(String id) async {
    final response = await http
        .delete(Uri.parse('${BackendConfig.baseUrl}/gaming/session/$id'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Delete gaming session');
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('The gaming service returned invalid data.');
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
