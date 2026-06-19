import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_event.dart';
import '../windows_ui/models/app_settings.dart';

class AlertService extends ChangeNotifier {
  AlertService._();

  static final AlertService instance = AlertService._();

  static const _historyKey = 'alertHistory';
  static const _maxHistoryEntries = 100;

  final List<AlertEvent> _history = [];
  final Map<String, bool> _activeAlerts = {};

  AppSettings _settings = const AppSettings();
  bool _initialized = false;
  bool _notificationsAvailable = false;

  List<AlertEvent> get history => List.unmodifiable(_history);

  Future<void> initialize(AppSettings settings) async {
    _settings = settings;

    if (_initialized) {
      return;
    }

    await _loadHistory();

    if (Platform.isWindows || Platform.isLinux) {
      try {
        await localNotifier.setup(
          appName: 'HardwareMon',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        _notificationsAvailable = true;
      } catch (error) {
        debugPrint('Desktop notifications unavailable: $error');
      }
    }

    _initialized = true;
  }

  void updateSettings(AppSettings settings) {
    final alertConfigurationChanged =
        settings.cpuAlerts != _settings.cpuAlerts ||
        settings.ramAlerts != _settings.ramAlerts ||
        settings.temperatureAlerts != _settings.temperatureAlerts ||
        settings.diskAlerts != _settings.diskAlerts ||
        settings.cpuTemperatureThreshold != _settings.cpuTemperatureThreshold ||
        settings.gpuTemperatureThreshold != _settings.gpuTemperatureThreshold ||
        settings.cpuUsageThreshold != _settings.cpuUsageThreshold ||
        settings.ramUsageThreshold != _settings.ramUsageThreshold ||
        settings.diskUsageThreshold != _settings.diskUsageThreshold;

    _settings = settings;
    if (alertConfigurationChanged) {
      _activeAlerts.clear();
    }
  }

  Future<void> evaluate({
    required double cpuTemperature,
    required double gpuTemperature,
    required double cpuUsage,
    required double ramUsage,
    required double diskUsage,
  }) async {
    if (!_initialized) {
      await initialize(_settings);
    }

    final checks = [
      _AlertCheck(
        key: 'cpu_temperature',
        label: 'CPU temperature',
        value: cpuTemperature,
        threshold: _settings.cpuTemperatureThreshold,
        unit: '°C',
        enabled: _settings.temperatureAlerts,
        recoveryMargin: 3,
      ),
      _AlertCheck(
        key: 'gpu_temperature',
        label: 'GPU temperature',
        value: gpuTemperature,
        threshold: _settings.gpuTemperatureThreshold,
        unit: '°C',
        enabled: _settings.temperatureAlerts,
        recoveryMargin: 3,
      ),
      _AlertCheck(
        key: 'cpu_usage',
        label: 'CPU usage',
        value: cpuUsage,
        threshold: _settings.cpuUsageThreshold,
        unit: '%',
        enabled: _settings.cpuAlerts,
        recoveryMargin: 5,
      ),
      _AlertCheck(
        key: 'ram_usage',
        label: 'RAM usage',
        value: ramUsage,
        threshold: _settings.ramUsageThreshold,
        unit: '%',
        enabled: _settings.ramAlerts,
        recoveryMargin: 5,
      ),
      _AlertCheck(
        key: 'disk_usage',
        label: 'Disk usage',
        value: diskUsage,
        threshold: _settings.diskUsageThreshold,
        unit: '%',
        enabled: _settings.diskAlerts,
        recoveryMargin: 2,
      ),
    ];

    for (final check in checks) {
      await _evaluateCheck(check);
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    notifyListeners();
  }

  Future<void> _evaluateCheck(_AlertCheck check) async {
    if (!check.enabled) {
      _activeAlerts[check.key] = false;
      return;
    }

    // Temperature sensors can be unavailable and report zero.
    if (check.value <= 0) {
      return;
    }

    final isActive = _activeAlerts[check.key] ?? false;

    if (isActive) {
      if (check.value <= check.threshold - check.recoveryMargin) {
        _activeAlerts[check.key] = false;
      }
      return;
    }

    if (check.value < check.threshold) {
      return;
    }

    _activeAlerts[check.key] = true;
    await _trigger(check);
  }

  Future<void> _trigger(_AlertCheck check) async {
    final event = AlertEvent(
      metricKey: check.key,
      metricLabel: check.label,
      value: check.value,
      threshold: check.threshold,
      unit: check.unit,
      occurredAt: DateTime.now(),
    );

    _history.insert(0, event);
    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(_maxHistoryEntries, _history.length);
    }

    try {
      await _saveHistory();
    } catch (error) {
      debugPrint('Failed to save alert history: $error');
    }
    notifyListeners();

    if (!_notificationsAvailable) {
      return;
    }

    try {
      final notification = LocalNotification(
        identifier: '${check.key}-${event.occurredAt.millisecondsSinceEpoch}',
        title: 'HardwareMon alert',
        body:
            '${check.label} reached ${_formatValue(check.value)}${check.unit} '
            '(threshold ${_formatValue(check.threshold)}${check.unit}).',
        silent: !_settings.alertSounds,
      );
      await notification.show();
    } catch (error) {
      debugPrint('Failed to show desktop notification: $error');
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_historyKey);

    if (encoded == null || encoded.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      _history
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(AlertEvent.fromJson)
              .take(_maxHistoryEntries),
        );
      notifyListeners();
    } catch (error) {
      debugPrint('Failed to load alert history: $error');
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(_history.map((event) => event.toJson()).toList()),
    );
  }

  String _formatValue(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class _AlertCheck {
  final String key;
  final String label;
  final double value;
  final double threshold;
  final String unit;
  final bool enabled;
  final double recoveryMargin;

  const _AlertCheck({
    required this.key,
    required this.label,
    required this.value,
    required this.threshold,
    required this.unit,
    required this.enabled,
    required this.recoveryMargin,
  });
}
