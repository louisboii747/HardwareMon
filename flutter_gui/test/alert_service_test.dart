import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/services/alert_service.dart';
import 'package:flutter_gui/windows_ui/models/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alerts trigger once, persist, and rearm after recovery', () async {
    SharedPreferences.setMockInitialValues({});

    const settings = AppSettings(
      cpuAlerts: true,
      cpuUsageThreshold: 90,
      alertSounds: false,
    );

    final service = AlertService.instance;
    await service.initialize(settings);
    service.updateSettings(settings);
    await service.clearHistory();

    await service.evaluate(
      cpuTemperature: 40,
      gpuTemperature: 40,
      cpuUsage: 95,
      ramUsage: 20,
      diskUsage: 20,
    );

    expect(service.history, hasLength(1));
    expect(service.history.first.metricKey, 'cpu_usage');

    await service.evaluate(
      cpuTemperature: 40,
      gpuTemperature: 40,
      cpuUsage: 97,
      ramUsage: 20,
      diskUsage: 20,
    );
    expect(service.history, hasLength(1));

    service.updateSettings(settings.copyWith(theme: 'Light'));
    await service.evaluate(
      cpuTemperature: 40,
      gpuTemperature: 40,
      cpuUsage: 97,
      ramUsage: 20,
      diskUsage: 20,
    );
    expect(service.history, hasLength(1));

    await service.evaluate(
      cpuTemperature: 40,
      gpuTemperature: 40,
      cpuUsage: 80,
      ramUsage: 20,
      diskUsage: 20,
    );
    await service.evaluate(
      cpuTemperature: 40,
      gpuTemperature: 40,
      cpuUsage: 95,
      ramUsage: 20,
      diskUsage: 20,
    );

    expect(service.history, hasLength(2));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('alertHistory'), isNotEmpty);
  });
}
