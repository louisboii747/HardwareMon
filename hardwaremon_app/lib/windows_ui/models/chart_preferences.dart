import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum ChartPreference { smoothLines, areaFill, gridLines, animations }

class ChartPreferences extends ChangeNotifier {
  static const _smoothLinesKey = 'chartSmoothLines';
  static const _areaFillKey = 'chartAreaFill';
  static const _gridLinesKey = 'chartGridLines';
  static const _animationsKey = 'chartAnimations';

  final SettingsService _settingsService;

  ChartPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  bool smoothLines = true;
  bool areaFill = true;
  bool gridLines = true;
  bool animations = true;

  Duration get animationDuration =>
      animations ? const Duration(milliseconds: 700) : Duration.zero;

  Future<void> load() async {
    smoothLines = await _settingsService.getBool(_smoothLinesKey, true);
    areaFill = await _settingsService.getBool(_areaFillKey, true);
    gridLines = await _settingsService.getBool(_gridLinesKey, true);
    animations = await _settingsService.getBool(_animationsKey, true);
    notifyListeners();
  }

  Future<void> setPreference(ChartPreference preference, bool value) async {
    late final String key;

    switch (preference) {
      case ChartPreference.smoothLines:
        smoothLines = value;
        key = _smoothLinesKey;
        break;
      case ChartPreference.areaFill:
        areaFill = value;
        key = _areaFillKey;
        break;
      case ChartPreference.gridLines:
        gridLines = value;
        key = _gridLinesKey;
        break;
      case ChartPreference.animations:
        animations = value;
        key = _animationsKey;
        break;
    }

    notifyListeners();
    await _settingsService.setBool(key, value);
  }

  bool valueFor(ChartPreference preference) {
    return switch (preference) {
      ChartPreference.smoothLines => smoothLines,
      ChartPreference.areaFill => areaFill,
      ChartPreference.gridLines => gridLines,
      ChartPreference.animations => animations,
    };
  }
}
