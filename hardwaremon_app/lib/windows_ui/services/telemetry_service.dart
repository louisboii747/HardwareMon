import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/alert_service.dart';
import 'settings_service.dart';
import '../core/backend_config.dart';
import '../models/telemetry_sample.dart';
import '../utils/time_axis.dart';

class TelemetryService extends ChangeNotifier {
  static const _maxLiveSamples = 3600;

  int cpuUsage = 0;
  int cpuTemp = 0;
  int ramUsage = 0;
  int diskUsage = 0;
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
  final List<TelemetrySample> cpuHistory = [];
  final List<TelemetrySample> cpuTempHistory = [];
  final List<TelemetrySample> cpuClockHistory = [];
  final List<TelemetrySample> cpuPowerHistory = [];
  final List<TelemetrySample> ramHistory = [];
  final List<TelemetrySample> ramUsedHistory = [];
  final List<TelemetrySample> ramAvailableHistory = [];
  final List<TelemetrySample> ramTotalHistory = [];
  final List<TelemetrySample> gpuTempHistory = [];
  final List<TelemetrySample> gpuUsageHistory = [];
  final List<TelemetrySample> gpuPowerHistory = [];
  final List<TelemetrySample> gpuVramUsedHistory = [];

  // Historical database telemetry
  final List<TelemetrySample> historicalCpuHistory = [];
  final List<TelemetrySample> historicalRamHistory = [];
  final List<TelemetrySample> historicalGpuHistory = [];

  Timer? _timer;
  Duration _refreshDuration = const Duration(seconds: 1);
  bool _fetchInProgress = false;
  int _historyRequestId = 0;

  bool isPaused = false;
  bool isRefreshing = false;
  bool isHistoryLoading = false;
  DateTime? lastUpdated;
  String? lastError;
  DateTime sessionStatisticsStartedAt = DateTime.now();
  TelemetryTimeRange historicalRange = TelemetryTimeRange.last1Hour;

  Future<void> fetchStats() async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;

    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/stats'),
      );

      final data = jsonDecode(response.body);

      cpuUsage = data['cpu'] ?? 0;
      cpuTemp = data['cpu_temp'] ?? 0;
      ramUsage = data['ram'] ?? 0;
      diskUsage = data['disk'] ?? 0;
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

      final sampledAt = DateTime.now();
      _appendSample(cpuHistory, cpuUsage.toDouble(), sampledAt);
      _appendSample(cpuTempHistory, cpuTemp.toDouble(), sampledAt);
      _appendSample(cpuClockHistory, cpuClockGHz, sampledAt);
      _appendSample(cpuPowerHistory, cpuPower, sampledAt);
      _appendSample(ramHistory, ramUsage.toDouble(), sampledAt);
      _appendSample(ramUsedHistory, ramUsed, sampledAt);
      _appendSample(ramAvailableHistory, ramAvailable, sampledAt);
      _appendSample(ramTotalHistory, ramTotal, sampledAt);
      _appendSample(gpuTempHistory, gpuTemp.toDouble(), sampledAt);
      _appendSample(gpuUsageHistory, gpuUsage.toDouble(), sampledAt);
      _appendSample(gpuPowerHistory, gpuPower, sampledAt);
      _appendSample(gpuVramUsedHistory, gpuVramUsed, sampledAt);

      await AlertService.instance.evaluate(
        cpuTemperature: cpuTemp.toDouble(),
        gpuTemperature: gpuTemp.toDouble(),
        cpuUsage: cpuUsage.toDouble(),
        ramUsage: ramUsage.toDouble(),
        diskUsage: diskUsage.toDouble(),
      );

      lastUpdated = sampledAt;
      lastError = null;
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      debugPrint('Telemetry fetch failed: $e');
      notifyListeners();
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<void> loadHistory({TelemetryTimeRange? range}) async {
    final requestId = ++_historyRequestId;
    isHistoryLoading = true;
    notifyListeners();

    try {
      final requestedRange = range ?? historicalRange;
      final uri = Uri.parse('${BackendConfig.baseUrl}/history').replace(
        queryParameters: {
          'range_seconds': '${requestedRange.duration.inSeconds}',
          'points': '720',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw StateError('History request failed (${response.statusCode})');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final cpuSamples = <TelemetrySample>[];
      final ramSamples = <TelemetrySample>[];
      final gpuSamples = <TelemetrySample>[];

      for (final item in data.reversed) {
        final timestamp = _parseHistoryTimestamp(item['timestamp']);

        cpuSamples.add(
          TelemetrySample(
            timestamp: timestamp,
            value: (item['cpu_usage'] ?? 0).toDouble(),
          ),
        );
        ramSamples.add(
          TelemetrySample(
            timestamp: timestamp,
            value: (item['ram_usage'] ?? 0).toDouble(),
          ),
        );
        gpuSamples.add(
          TelemetrySample(
            timestamp: timestamp,
            value: (item['gpu_usage'] ?? 0).toDouble(),
          ),
        );
      }

      if (requestId != _historyRequestId) return;

      historicalCpuHistory
        ..clear()
        ..addAll(cpuSamples);
      historicalRamHistory
        ..clear()
        ..addAll(ramSamples);
      historicalGpuHistory
        ..clear()
        ..addAll(gpuSamples);
      historicalRange = requestedRange;
      lastError = null;
      notifyListeners();
    } catch (e) {
      if (requestId != _historyRequestId) return;
      lastError = e.toString();
      debugPrint('History fetch failed: $e');
      notifyListeners();
    } finally {
      if (requestId == _historyRequestId) {
        isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> start() async {
    final settings = await SettingsService().loadSettings();
    AlertService.instance.updateSettings(settings);

    switch (settings.refreshInterval) {
      case '2s':
        _refreshDuration = const Duration(seconds: 2);
        break;

      case '5s':
        _refreshDuration = const Duration(seconds: 5);
        break;

      default:
        _refreshDuration = const Duration(seconds: 1);
    }

    isPaused = false;
    await refreshNow(includeHistory: true);
    _scheduleTimer();
  }

  Future<void> restart() async {
    stop();
    await start();
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> refreshNow({bool includeHistory = false}) async {
    if (isRefreshing) return;

    isRefreshing = true;
    notifyListeners();

    try {
      await fetchStats();
      if (includeHistory) {
        await loadHistory();
      }
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> setPaused(bool paused) async {
    if (isPaused == paused) return;

    isPaused = paused;
    _timer?.cancel();
    notifyListeners();

    if (!paused) {
      await refreshNow();
      _scheduleTimer();
    }
  }

  Future<void> togglePaused() => setPaused(!isPaused);

  Future<void> setHistoricalRange(TelemetryTimeRange range) async {
    if (historicalRange == range && historicalCpuHistory.isNotEmpty) return;
    historicalRange = range;
    notifyListeners();
    await loadHistory(range: range);
  }

  void resetSessionStatistics() {
    sessionStatisticsStartedAt = DateTime.now();
    notifyListeners();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (isPaused) return;

    _timer = Timer.periodic(_refreshDuration, (_) => fetchStats());
  }

  void _appendSample(
    List<TelemetrySample> history,
    double value,
    DateTime timestamp,
  ) {
    history.add(TelemetrySample(timestamp: timestamp, value: value));

    if (history.length > _maxLiveSamples) {
      history.removeRange(0, history.length - _maxLiveSamples);
    }
  }

  DateTime _parseHistoryTimestamp(dynamic rawTimestamp) {
    final value = rawTimestamp?.toString().trim();
    if (value == null || value.isEmpty) return DateTime.now();

    final isoValue = value.contains('T') ? value : value.replaceFirst(' ', 'T');
    final hasTimezone =
        isoValue.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(isoValue);
    final parsed = DateTime.tryParse(hasTimezone ? isoValue : '${isoValue}Z');

    return (parsed ?? DateTime.now().toUtc()).toLocal();
  }
}
