import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/optimization_models.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';

void main() {
  test('maintenance evidence decodes without inventing unavailable values', () {
    final snapshot = OptimizationSnapshot.fromJson({
      'platform': 'Linux',
      'maintenance': {
        'uptime_seconds': 1296000,
        'restart_recommended': true,
        'bios': {'vendor': 'Example', 'version': '1.2.3', 'date': null},
        'battery': {'percent': 73.5, 'plugged_in': false},
      },
    });

    expect(snapshot.uptimeSeconds, 1296000);
    expect(snapshot.restartRecommended, isTrue);
    expect(snapshot.biosVendor, 'Example');
    expect(snapshot.biosVersion, '1.2.3');
    expect(snapshot.biosDate, isNull);
    expect(snapshot.batteryPercent, 73.5);
    expect(snapshot.batteryPluggedIn, isFalse);
  });

  test('long uptime produces a safe restart recommendation', () {
    final snapshot = OptimizationSnapshot.fromJson({
      'maintenance': {
        'uptime_seconds': 31 * 24 * 60 * 60,
        'restart_recommended': true,
      },
    });
    final recommendations = const MaintenanceRecommendationEngine().evaluate(
      OptimizationRecommendationContext(
        optimization: snapshot,
        storage: null,
        averageRam: 0,
        peakRam: 0,
        averageCpuTemperature: 0,
        peakCpuTemperature: 0,
      ),
    );

    expect(recommendations, hasLength(1));
    expect(recommendations.single.id, 'long-uptime');
    expect(recommendations.single.details, contains('never restarts'));
  });

  test('health scores react to sustained pressure', () {
    final now = DateTime(2026, 6, 21);
    final healthy = OptimizationHealthScores.calculate(
      cpuUsage: 20,
      ramUsage: 45,
      cpuTemperature: 55,
      gpuTemperature: 52,
      cpuHistory: [TelemetrySample(timestamp: now, value: 20)],
      ramHistory: [TelemetrySample(timestamp: now, value: 45)],
      cpuTemperatureHistory: [TelemetrySample(timestamp: now, value: 55)],
      gpuTemperatureHistory: [TelemetrySample(timestamp: now, value: 52)],
    );
    final pressured = OptimizationHealthScores.calculate(
      cpuUsage: 95,
      ramUsage: 94,
      cpuTemperature: 96,
      gpuTemperature: 90,
      cpuHistory: [TelemetrySample(timestamp: now, value: 95)],
      ramHistory: [TelemetrySample(timestamp: now, value: 94)],
      cpuTemperatureHistory: [TelemetrySample(timestamp: now, value: 96)],
      gpuTemperatureHistory: [TelemetrySample(timestamp: now, value: 90)],
    );

    expect(healthy.overall, greaterThan(pressured.overall));
    expect(pressured.memory, lessThan(healthy.memory));
    expect(pressured.thermal, lessThan(healthy.thermal));
  });

  test('recommendation engines remain independently composable', () {
    final recommendations = buildOptimizationRecommendations(
      const OptimizationRecommendationContext(
        optimization: null,
        storage: null,
        averageRam: 84,
        peakRam: 92,
        averageCpuTemperature: 80,
        peakCpuTemperature: 91,
      ),
    );

    expect(
      recommendations.map((item) => item.id),
      containsAll(['memory-pressure', 'cpu-temperature']),
    );
  });
}
