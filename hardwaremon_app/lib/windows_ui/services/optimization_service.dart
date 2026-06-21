import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/backend_config.dart';
import '../models/optimization_models.dart';

class OptimizationService {
  Future<OptimizationSnapshot> fetchSnapshot() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/optimization'))
        .timeout(const Duration(seconds: 18));
    _ensureSuccess(response, 'Optimisation analysis');
    return OptimizationSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<void> setStartupEnabled(String id, bool enabled) async {
    final response = await http
        .patch(
          Uri.parse('${BackendConfig.baseUrl}/optimization/startup/$id'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Startup application update');
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
