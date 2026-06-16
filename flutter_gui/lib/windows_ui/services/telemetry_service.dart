import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import '../core/backend_config.dart';

class TelemetryService extends ChangeNotifier {
  int cpuUsage = 0;
  int cpuTemp = 0;
  int ramUsage = 0;
  int gpuTemp = 0;
  int gpuUsage = 0;

  double gpuPower = 0;
  double gpuVramUsed = 0;

  double cpuPower = 0;
  double cpuClock = 0;

  double ramUsed = 0;
  double ramAvailable = 0;
  double ramTotal = 0;

  double get cpuClockGHz => cpuClock / 1000;

  String cpuName = 'Loading...';

  // Live telemetry history
  final List<double> cpuHistory = [];
  final List<double> ramHistory = [];
  final List<double> gpuTempHistory = [];
  final List<double> gpuUsageHistory = [];

  // Historical database telemetry
  final List<double> historicalCpuHistory = [];
  final List<double> historicalRamHistory = [];
  final List<double> historicalGpuHistory = [];

  Timer? _timer;

  Future<void> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/stats'),
      );

      final data = jsonDecode(response.body);

      cpuUsage = data['cpu'] ?? 0;
      cpuTemp = data['cpu_temp'] ?? 0;
      ramUsage = data['ram'] ?? 0;
      gpuTemp = data['gpu_temp'] ?? 0;
      gpuUsage = data['gpu_usage'] ?? 0;

      cpuPower = (data['cpu_power'] ?? 0).toDouble();
      cpuClock = (data['cpu_clock'] ?? 0).toDouble();

      gpuPower = (data['gpu_power'] ?? 0).toDouble();
      gpuVramUsed = (data['gpu_vram_used'] ?? 0).toDouble();

      ramUsed = (data['ram_used'] ?? 0).toDouble();
      ramAvailable = (data['ram_available'] ?? 0).toDouble();
      ramTotal = (data['ram_total'] ?? 0).toDouble();

      cpuName = data['cpu_name'] ?? 'Unknown CPU';

      cpuHistory.add(cpuUsage.toDouble());
      ramHistory.add(ramUsage.toDouble());
      gpuTempHistory.add(gpuTemp.toDouble());
      gpuUsageHistory.add(gpuUsage.toDouble());

      if (cpuHistory.length > 30) {
        cpuHistory.removeAt(0);
      }

      if (ramHistory.length > 30) {
        ramHistory.removeAt(0);
      }

      if (gpuTempHistory.length > 30) {
        gpuTempHistory.removeAt(0);
      }

      if (gpuUsageHistory.length > 30) {
        gpuUsageHistory.removeAt(0);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Telemetry fetch failed: $e');
    }
  }

  Future<void> loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/history?limit=100'),
      );

      final List<dynamic> data = jsonDecode(response.body);

      historicalCpuHistory.clear();
      historicalRamHistory.clear();
      historicalGpuHistory.clear();

      for (final item in data.reversed) {
        historicalCpuHistory.add((item['cpu_usage'] ?? 0).toDouble());

        historicalRamHistory.add((item['ram_usage'] ?? 0).toDouble());

        historicalGpuHistory.add((item['gpu_usage'] ?? 0).toDouble());
      }

      notifyListeners();
    } catch (e) {
      debugPrint('History fetch failed: $e');
    }
  }

  Future<void> start() async {
    final settings = await SettingsService().loadSettings();

    Duration refreshDuration;

    switch (settings.refreshInterval) {
      case '2s':
        refreshDuration = const Duration(seconds: 2);
        break;

      case '5s':
        refreshDuration = const Duration(seconds: 5);
        break;

      default:
        refreshDuration = const Duration(seconds: 1);
    }

    await fetchStats();
    await loadHistory();

    _timer?.cancel();

    _timer = Timer.periodic(refreshDuration, (_) => fetchStats());
  }

  Future<void> restart() async {
    stop();
    await start();
  }

  void stop() {
    _timer?.cancel();
  }
}
