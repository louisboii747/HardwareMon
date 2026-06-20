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

    final restored = ChartPreferences();
    await restored.load();

    expect(restored.smoothLines, isFalse);
    expect(restored.areaFill, isFalse);
    expect(restored.gridLines, isFalse);
    expect(restored.animations, isFalse);
    expect(restored.animationDuration, Duration.zero);
  });
}
