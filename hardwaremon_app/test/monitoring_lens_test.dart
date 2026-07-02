import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/monitoring_lens.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_insights.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('monitoring lens persists across app sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = MonitoringLensPreferences();
    await preferences.setLens(MonitoringLens.quiet);

    final restored = MonitoringLensPreferences();
    await restored.load();

    expect(restored.lens, MonitoringLens.quiet);
  });

  test(
    'monitoring lens changes score weighting without changing telemetry',
    () {
      final now = DateTime.now();
      List<TelemetrySample> samples(double value) => [
        for (var index = 0; index < 8; index++)
          TelemetrySample(
            timestamp: now.subtract(Duration(seconds: 8 - index)),
            value: value,
          ),
      ];

      final summary = buildTelemetrySessionSummary(
        cpuUsage: 96,
        ramUsage: 42,
        gpuUsage: 20,
        cpuTemperature: 52,
        gpuTemperature: 48,
        cpuHistory: samples(96),
        ramHistory: samples(42),
        gpuHistory: samples(20),
        cpuTemperatureHistory: samples(52),
        gpuTemperatureHistory: samples(48),
      );

      SystemHealthProfile profile(MonitoringLens lens) =>
          buildSystemHealthProfile(
            summary: summary,
            cpuUsage: 96,
            ramUsage: 42,
            gpuUsage: 20,
            cpuTemperature: 52,
            gpuTemperature: 48,
            cpuPower: 45,
            gpuPower: 12,
            lens: lens,
          );

      expect(
        profile(MonitoringLens.performance).overallScore,
        lessThan(profile(MonitoringLens.quiet).overallScore),
      );
    },
  );
}
