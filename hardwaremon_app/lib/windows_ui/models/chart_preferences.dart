import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum ChartPreference {
  smoothLines,
  areaFill,
  gridLines,
  animations,
  ambientEffects,
  telemetryTicker,
}

class ChartPreferences extends ChangeNotifier {
  static const _smoothLinesKey = 'chartSmoothLines';
  static const _areaFillKey = 'chartAreaFill';
  static const _gridLinesKey = 'chartGridLines';
  static const _animationsKey = 'chartAnimations';
  static const _ambientEffectsKey = 'ambientSystemEffects';
  static const _telemetryTickerKey = 'telemetryTicker';

  final SettingsService _settingsService;

  ChartPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  bool smoothLines = true;
  bool areaFill = true;
  bool gridLines = true;
  bool animations = true;
  bool ambientEffects = true;
  bool telemetryTicker = true;

  Duration get animationDuration =>
      animations ? const Duration(milliseconds: 700) : Duration.zero;

  Future<void> load() async {
    smoothLines = await _settingsService.getBool(_smoothLinesKey, true);
    areaFill = await _settingsService.getBool(_areaFillKey, true);
    gridLines = await _settingsService.getBool(_gridLinesKey, true);
    animations = await _settingsService.getBool(_animationsKey, true);
    ambientEffects = await _settingsService.getBool(_ambientEffectsKey, true);
    telemetryTicker = await _settingsService.getBool(_telemetryTickerKey, true);
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
      case ChartPreference.ambientEffects:
        ambientEffects = value;
        key = _ambientEffectsKey;
        break;
      case ChartPreference.telemetryTicker:
        telemetryTicker = value;
        key = _telemetryTickerKey;
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
      ChartPreference.ambientEffects => ambientEffects,
      ChartPreference.telemetryTicker => telemetryTicker,
    };
  }

  Future<void> resetDefaults() async {
    smoothLines = true;
    areaFill = true;
    gridLines = true;
    animations = true;
    ambientEffects = true;
    telemetryTicker = true;
    notifyListeners();

    await Future.wait([
      _settingsService.setBool(_smoothLinesKey, true),
      _settingsService.setBool(_areaFillKey, true),
      _settingsService.setBool(_gridLinesKey, true),
      _settingsService.setBool(_animationsKey, true),
      _settingsService.setBool(_ambientEffectsKey, true),
      _settingsService.setBool(_telemetryTickerKey, true),
    ]);
  }
}
