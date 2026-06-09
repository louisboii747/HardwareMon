import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/backend_config.dart';

class TelemetryService extends ChangeNotifier {
  int cpuUsage = 0;
  int ramUsage = 0;
  int gpuTemp = 0;

  String cpuName = 'Loading...';

  final List<double> cpuHistory = [];
  final List<double> ramHistory = [];
  final List<double> gpuTempHistory = [];

  Timer? _timer;

  Future<void> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/stats'),
      );

      final data = jsonDecode(response.body);

      cpuUsage = data['cpu'] ?? 0;
      ramUsage = data['ram'] ?? 0;
      gpuTemp = data['gpu_temp'] ?? 0;

      cpuName = data['cpu_name'] ?? 'Unknown CPU';

      cpuHistory.add(cpuUsage.toDouble());
      ramHistory.add(ramUsage.toDouble());
      gpuTempHistory.add(gpuTemp.toDouble());

      if (cpuHistory.length > 30) {
        cpuHistory.removeAt(0);
      }

      if (ramHistory.length > 30) {
        ramHistory.removeAt(0);
      }

      if (gpuTempHistory.length > 30) {
        gpuTempHistory.removeAt(0);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Telemetry fetch failed: $e');
    }
  }

  void start() {
    fetchStats();

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => fetchStats());
  }

  void stop() {
    _timer?.cancel();
  }
}
