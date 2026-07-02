import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum MonitoringLens { balanced, performance, quiet, efficiency, reliability }

extension MonitoringLensDetails on MonitoringLens {
  String get label => switch (this) {
    MonitoringLens.balanced => 'Balanced',
    MonitoringLens.performance => 'Performance',
    MonitoringLens.quiet => 'Quiet',
    MonitoringLens.efficiency => 'Efficiency',
    MonitoringLens.reliability => 'Reliability',
  };

  String get description => switch (this) {
    MonitoringLens.balanced => 'Equal attention across everyday system health',
    MonitoringLens.performance =>
      'Prioritise compute headroom and sustained load',
    MonitoringLens.quiet => 'Prioritise thermals, cooling pressure, and power',
    MonitoringLens.efficiency => 'Prioritise useful work per watt',
    MonitoringLens.reliability => 'Prioritise memory and thermal stability',
  };
}

class MonitoringLensPreferences extends ChangeNotifier {
  static const _key = 'monitoringLens';

  final SettingsService _settingsService;
  MonitoringLens lens = MonitoringLens.balanced;

  MonitoringLensPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  Future<void> load() async {
    final stored = await _settingsService.getString(
      _key,
      MonitoringLens.balanced.name,
    );
    lens = MonitoringLens.values.firstWhere(
      (candidate) => candidate.name == stored,
      orElse: () => MonitoringLens.balanced,
    );
    notifyListeners();
  }

  Future<void> setLens(MonitoringLens value) async {
    if (lens == value) return;
    lens = value;
    notifyListeners();
    await _settingsService.setString(_key, value.name);
  }
}
