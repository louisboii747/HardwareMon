import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backend_config.dart';
import '../models/network_models.dart';

class NetworkService {
  static const recentTargetsKey = 'networkPingRecentTargets';
  static const favouriteTargetsKey = 'networkPingFavouriteTargets';
  static const lastPingResultKey = 'networkPingLastResult';
  static const selectedInterfaceKey = 'networkSelectedInterface';
  static const _maximumRecentTargets = 8;

  Future<NetworkSnapshot> fetchSnapshot() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/network'))
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      throw StateError('Network telemetry failed (${response.statusCode})');
    }

    return NetworkSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<PingResult> ping(
    String target, {
    int count = 4,
    double timeout = 2,
  }) async {
    final response = await http
        .post(
          Uri.parse('${BackendConfig.baseUrl}/network/ping'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'target': target,
            'count': count,
            'timeout': timeout,
          }),
        )
        .timeout(Duration(seconds: ((count * timeout) + 6).ceil()));

    if (response.statusCode != 200) {
      throw StateError('Ping request failed (${response.statusCode})');
    }

    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    data['checked_at'] = DateTime.now().toIso8601String();
    final result = PingResult.fromJson(data);
    await _saveResult(result);
    return result;
  }

  Future<List<String>> loadRecentTargets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(recentTargetsKey) ?? const [];
  }

  Future<List<String>> loadFavouriteTargets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(favouriteTargetsKey) ?? const [];
  }

  Future<String?> loadSelectedInterface() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedInterfaceKey);
  }

  Future<void> saveSelectedInterface(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedInterfaceKey, name);
  }

  Future<List<String>> toggleFavourite(String target) async {
    final normalized = target.trim();
    if (normalized.isEmpty) return loadFavouriteTargets();

    final prefs = await SharedPreferences.getInstance();
    final favourites = prefs.getStringList(favouriteTargetsKey) ?? <String>[];
    if (favourites.contains(normalized)) {
      favourites.remove(normalized);
    } else {
      favourites.insert(0, normalized);
    }
    await prefs.setStringList(favouriteTargetsKey, favourites);
    return favourites;
  }

  Future<void> clearRecentTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(recentTargetsKey);
  }

  Future<void> _saveResult(PingResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastPingResultKey, jsonEncode(result.toJson()));

    if (result.resolvedHost == null || result.target.trim().isEmpty) return;
    final recent = prefs.getStringList(recentTargetsKey) ?? <String>[];
    recent.remove(result.target);
    recent.insert(0, result.target);
    if (recent.length > _maximumRecentTargets) {
      recent.removeRange(_maximumRecentTargets, recent.length);
    }
    await prefs.setStringList(recentTargetsKey, recent);
  }
}
