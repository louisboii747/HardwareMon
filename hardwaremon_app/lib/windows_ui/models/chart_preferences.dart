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

enum GraphAnimationSpeed { relaxed, balanced, fast }

extension GraphAnimationSpeedDetails on GraphAnimationSpeed {
  String get label => switch (this) {
    GraphAnimationSpeed.relaxed => 'Relaxed',
    GraphAnimationSpeed.balanced => 'Balanced',
    GraphAnimationSpeed.fast => 'Fast',
  };
}

class ChartPreferences extends ChangeNotifier {
  static const _smoothLinesKey = 'chartSmoothLines';
  static const _areaFillKey = 'chartAreaFill';
  static const _gridLinesKey = 'chartGridLines';
  static const _animationsKey = 'chartAnimations';
  static const _ambientEffectsKey = 'ambientSystemEffects';
  static const _telemetryTickerKey = 'telemetryTicker';
  static const _smoothnessKey = 'chartSmoothness';
  static const _thicknessKey = 'chartThickness';
  static const _timelineDensityKey = 'chartTimelineDensity';
  static const _animationSpeedKey = 'chartAnimationSpeed';

  final SettingsService _settingsService;

  ChartPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  bool smoothLines = true;
  bool areaFill = true;
  bool gridLines = true;
  bool animations = true;
  bool ambientEffects = true;
  bool telemetryTicker = true;
  double smoothness = 0.38;
  double thickness = 2;
  double timelineDensity = 1;
  GraphAnimationSpeed animationSpeed = GraphAnimationSpeed.balanced;

  Duration get animationDuration {
    if (!animations) return Duration.zero;
    return switch (animationSpeed) {
      GraphAnimationSpeed.relaxed => const Duration(milliseconds: 1050),
      GraphAnimationSpeed.balanced => const Duration(milliseconds: 700),
      GraphAnimationSpeed.fast => const Duration(milliseconds: 360),
    };
  }

  Future<void> load() async {
    smoothLines = await _settingsService.getBool(_smoothLinesKey, true);
    areaFill = await _settingsService.getBool(_areaFillKey, true);
    gridLines = await _settingsService.getBool(_gridLinesKey, true);
    animations = await _settingsService.getBool(_animationsKey, true);
    ambientEffects = await _settingsService.getBool(_ambientEffectsKey, true);
    telemetryTicker = await _settingsService.getBool(_telemetryTickerKey, true);
    smoothness = await _settingsService.getDouble(_smoothnessKey, 0.38);
    thickness = await _settingsService.getDouble(_thicknessKey, 2);
    timelineDensity = await _settingsService.getDouble(_timelineDensityKey, 1);
    final storedAnimationSpeed = await _settingsService.getString(
      _animationSpeedKey,
      GraphAnimationSpeed.balanced.name,
    );
    animationSpeed = GraphAnimationSpeed.values.firstWhere(
      (value) => value.name == storedAnimationSpeed,
      orElse: () => GraphAnimationSpeed.balanced,
    );
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

  Future<void> setSmoothness(double value) async {
    smoothness = value.clamp(0, 0.55);
    smoothLines = smoothness > 0.02;
    notifyListeners();
    await Future.wait([
      _settingsService.setDouble(_smoothnessKey, smoothness),
      _settingsService.setBool(_smoothLinesKey, smoothLines),
    ]);
  }

  Future<void> setThickness(double value) async {
    thickness = value.clamp(1, 5);
    notifyListeners();
    await _settingsService.setDouble(_thicknessKey, thickness);
  }

  Future<void> setTimelineDensity(double value) async {
    timelineDensity = value.clamp(0.55, 1.8);
    notifyListeners();
    await _settingsService.setDouble(_timelineDensityKey, timelineDensity);
  }

  Future<void> setAnimationSpeed(GraphAnimationSpeed value) async {
    animationSpeed = value;
    notifyListeners();
    await _settingsService.setString(_animationSpeedKey, value.name);
  }

  Future<void> resetDefaults() async {
    smoothLines = true;
    areaFill = true;
    gridLines = true;
    animations = true;
    ambientEffects = true;
    telemetryTicker = true;
    smoothness = 0.38;
    thickness = 2;
    timelineDensity = 1;
    animationSpeed = GraphAnimationSpeed.balanced;
    notifyListeners();

    await Future.wait([
      _settingsService.setBool(_smoothLinesKey, true),
      _settingsService.setBool(_areaFillKey, true),
      _settingsService.setBool(_gridLinesKey, true),
      _settingsService.setBool(_animationsKey, true),
      _settingsService.setBool(_ambientEffectsKey, true),
      _settingsService.setBool(_telemetryTickerKey, true),
      _settingsService.setDouble(_smoothnessKey, 0.38),
      _settingsService.setDouble(_thicknessKey, 2),
      _settingsService.setDouble(_timelineDensityKey, 1),
      _settingsService.setString(
        _animationSpeedKey,
        GraphAnimationSpeed.balanced.name,
      ),
    ]);
  }
}
