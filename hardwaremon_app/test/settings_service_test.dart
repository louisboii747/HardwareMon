import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/app_settings.dart';
import 'package:flutter_gui/windows_ui/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alert toggles and thresholds persist', () async {
    SharedPreferences.setMockInitialValues({});

    const expected = AppSettings(
      cpuAlerts: true,
      ramAlerts: true,
      temperatureAlerts: true,
      diskAlerts: true,
      alertSounds: false,
      cpuTemperatureThreshold: 82,
      gpuTemperatureThreshold: 88,
      cpuUsageThreshold: 91,
      ramUsageThreshold: 86,
      diskUsageThreshold: 93,
    );

    final service = SettingsService();
    await service.saveSettings(expected);
    final actual = await service.loadSettings();

    expect(actual.cpuAlerts, isTrue);
    expect(actual.ramAlerts, isTrue);
    expect(actual.temperatureAlerts, isTrue);
    expect(actual.diskAlerts, isTrue);
    expect(actual.alertSounds, isFalse);
    expect(actual.cpuTemperatureThreshold, 82);
    expect(actual.gpuTemperatureThreshold, 88);
    expect(actual.cpuUsageThreshold, 91);
    expect(actual.ramUsageThreshold, 86);
    expect(actual.diskUsageThreshold, 93);
  });
}
