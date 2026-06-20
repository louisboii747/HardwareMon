import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chart preferences persist across instances', () async {
    SharedPreferences.setMockInitialValues({});

    final preferences = ChartPreferences();
    await preferences.setPreference(ChartPreference.smoothLines, false);
    await preferences.setPreference(ChartPreference.areaFill, false);
    await preferences.setPreference(ChartPreference.gridLines, false);
    await preferences.setPreference(ChartPreference.animations, false);
    await preferences.setPreference(ChartPreference.ambientEffects, false);
    await preferences.setPreference(ChartPreference.telemetryTicker, false);

    final restored = ChartPreferences();
    await restored.load();

    expect(restored.smoothLines, isFalse);
    expect(restored.areaFill, isFalse);
    expect(restored.gridLines, isFalse);
    expect(restored.animations, isFalse);
    expect(restored.ambientEffects, isFalse);
    expect(restored.telemetryTicker, isFalse);
    expect(restored.animationDuration, Duration.zero);
  });

  test('experience preferences reset to premium defaults', () async {
    SharedPreferences.setMockInitialValues({
      'ambientSystemEffects': false,
      'telemetryTicker': false,
      'chartAnimations': false,
    });

    final preferences = ChartPreferences();
    await preferences.load();
    await preferences.resetDefaults();

    final restored = ChartPreferences();
    await restored.load();

    expect(restored.ambientEffects, isTrue);
    expect(restored.telemetryTicker, isTrue);
    expect(restored.animations, isTrue);
  });
}
