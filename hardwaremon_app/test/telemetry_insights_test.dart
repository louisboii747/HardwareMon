import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/telemetry_insights.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';

void main() {
  List<TelemetrySample> samples(List<double> values) {
    final now = DateTime.now();
    return [
      for (var index = 0; index < values.length; index++)
        TelemetrySample(
          timestamp: now.subtract(Duration(seconds: values.length - index)),
          value: values[index],
        ),
    ];
  }

  test('healthy telemetry session produces high score and healthy insight', () {
    final summary = buildTelemetrySessionSummary(
      cpuUsage: 24,
      ramUsage: 38,
      gpuUsage: 12,
      cpuTemperature: 52,
      gpuTemperature: 48,
      cpuHistory: samples([18, 20, 22, 21, 24, 23]),
      ramHistory: samples([34, 35, 36, 37, 38, 38]),
      gpuHistory: samples([8, 9, 10, 12, 11, 12]),
      cpuTemperatureHistory: samples([48, 50, 51, 52, 52, 51]),
      gpuTemperatureHistory: samples([44, 45, 46, 47, 48, 48]),
    );

    expect(summary.score, greaterThanOrEqualTo(85));
    expect(summary.headline, 'Excellent headroom');
    expect(summary.insights.single.severity, TelemetryInsightSeverity.healthy);
  });

  test('pressure and thermals produce critical recommendations', () {
    final summary = buildTelemetrySessionSummary(
      cpuUsage: 98,
      ramUsage: 92,
      gpuUsage: 86,
      cpuTemperature: 91,
      gpuTemperature: 84,
      cpuHistory: samples([80, 86, 91, 95, 98, 97]),
      ramHistory: samples([84, 86, 89, 91, 92, 92]),
      gpuHistory: samples([66, 72, 79, 82, 85, 86]),
      cpuTemperatureHistory: samples([78, 82, 86, 89, 91, 90]),
      gpuTemperatureHistory: samples([72, 76, 79, 82, 84, 83]),
    );

    expect(summary.score, lessThan(70));
    expect(
      summary.insights.map((insight) => insight.severity),
      contains(TelemetryInsightSeverity.critical),
    );
    expect(
      summary.insights.map((insight) => insight.title),
      contains('Resource ceiling reached'),
    );
  });

  test('health profile identifies the dominant live constraint', () {
    final summary = buildTelemetrySessionSummary(
      cpuUsage: 43,
      ramUsage: 91,
      gpuUsage: 18,
      cpuTemperature: 58,
      gpuTemperature: 50,
      cpuHistory: samples([38, 40, 42, 44, 43, 43]),
      ramHistory: samples([82, 84, 86, 88, 90, 91]),
      gpuHistory: samples([12, 14, 15, 17, 18, 18]),
      cpuTemperatureHistory: samples([54, 55, 56, 57, 58, 58]),
      gpuTemperatureHistory: samples([46, 47, 48, 49, 50, 50]),
    );

    final profile = buildSystemHealthProfile(
      summary: summary,
      cpuUsage: 43,
      ramUsage: 91,
      gpuUsage: 18,
      cpuTemperature: 58,
      gpuTemperature: 50,
      cpuPower: 52,
      gpuPower: 18,
    );

    expect(profile.bottleneck, contains('Memory'));
    expect(profile.observation, contains('Memory headroom'));
    expect(profile.signals, hasLength(4));
    expect(
      profile.signals
          .singleWhere(
            (signal) => signal.dimension == SystemHealthDimension.memory,
          )
          .score,
      lessThan(60),
    );
  });

  test(
    'health profile explains baseline calibration without fake certainty',
    () {
      final summary = buildTelemetrySessionSummary(
        cpuUsage: 0,
        ramUsage: 0,
        gpuUsage: 0,
        cpuTemperature: 0,
        gpuTemperature: 0,
        cpuHistory: const [],
        ramHistory: const [],
        gpuHistory: const [],
        cpuTemperatureHistory: const [],
        gpuTemperatureHistory: const [],
      );

      final profile = buildSystemHealthProfile(
        summary: summary,
        cpuUsage: 0,
        ramUsage: 0,
        gpuUsage: 0,
        cpuTemperature: 0,
        gpuTemperature: 0,
        cpuPower: 0,
        gpuPower: 0,
      );

      expect(profile.observation, contains('learning this session'));
      expect(profile.bottleneck, 'No active bottleneck');
      expect(profile.signals.last.detail, 'Power baseline pending');
    },
  );
}
