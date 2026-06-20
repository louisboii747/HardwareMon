import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_statistics.dart';

void main() {
  test('calculates current, min, average, max, and trend', () {
    final start = DateTime(2026, 6, 20, 10);
    final statistics = calculateTelemetryStatistics([
      TelemetrySample(timestamp: start, value: 20),
      TelemetrySample(
        timestamp: start.add(const Duration(seconds: 1)),
        value: 40,
      ),
      TelemetrySample(
        timestamp: start.add(const Duration(seconds: 2)),
        value: 30,
      ),
    ]);

    expect(statistics.current, 30);
    expect(statistics.minimum, 20);
    expect(statistics.average, 30);
    expect(statistics.maximum, 40);
    expect(statistics.delta, -10);
    expect(statistics.isFalling, isTrue);
    expect(statistics.sampleCount, 3);
  });

  test('session reset timestamp filters older samples', () {
    final start = DateTime(2026, 6, 20, 10);
    final statistics = calculateTelemetryStatistics([
      TelemetrySample(timestamp: start, value: 90),
      TelemetrySample(
        timestamp: start.add(const Duration(minutes: 1)),
        value: 30,
      ),
      TelemetrySample(
        timestamp: start.add(const Duration(minutes: 2)),
        value: 40,
      ),
    ], since: start.add(const Duration(seconds: 30)));

    expect(statistics.minimum, 30);
    expect(statistics.maximum, 40);
    expect(statistics.sampleCount, 2);
  });
}
