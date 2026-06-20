import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/utils/telemetry_chart.dart';
import 'package:flutter_gui/windows_ui/utils/time_axis.dart';

void main() {
  group('adaptiveTimeLabelCount', () {
    test('uses fewer labels on compact charts and more on wide charts', () {
      expect(adaptiveTimeLabelCount(240), 3);
      expect(adaptiveTimeLabelCount(720), 8);
      expect(adaptiveTimeLabelCount(1600), 10);
    });
  });

  group('formatTimeAxisTimestamp', () {
    final timestamp = DateTime(2026, 6, 15, 14, 7);

    test('uses clock labels through 24 hours', () {
      expect(
        formatTimeAxisTimestamp(timestamp, const Duration(minutes: 30)),
        '14:07',
      );
      expect(
        formatTimeAxisTimestamp(timestamp, const Duration(hours: 24)),
        '14:07',
      );
    });

    test('adds weekday context for multi-day ranges', () {
      expect(
        formatTimeAxisTimestamp(timestamp, const Duration(days: 3)),
        'Mon 14:07',
      );
    });

    test('uses concise dates for week and month ranges', () {
      expect(
        formatTimeAxisTimestamp(timestamp, const Duration(days: 7)),
        '15 Jun',
      );
      expect(
        formatTimeAxisTimestamp(timestamp, const Duration(days: 30)),
        '15 Jun',
      );
    });
  });

  test('generateTimeAxisTicks distributes major ticks evenly', () {
    final start = DateTime(2026, 6, 15, 10);
    final samples = [
      TelemetrySample(timestamp: start, value: 10),
      TelemetrySample(
        timestamp: start.add(const Duration(minutes: 30)),
        value: 40,
      ),
    ];

    final scale = generateTimeAxisTicks(samples: samples, width: 400);

    expect(scale.ticks, hasLength(5));
    expect(scale.ticks.first.x, 0);
    expect(scale.ticks.last.x, scale.maxX);
    expect(scale.ticks[2].x, closeTo(scale.maxX / 2, 0.001));
    expect(scale.ticks.first.label, '10:00');
    expect(scale.ticks.last.label, '10:30');
  });

  test('all future monitoring ranges remain available', () {
    expect(
      TelemetryTimeRange.values.map((range) => range.duration),
      containsAll([
        const Duration(minutes: 5),
        const Duration(minutes: 30),
        const Duration(hours: 1),
        const Duration(hours: 24),
        const Duration(days: 7),
        const Duration(days: 30),
      ]),
    );
  });

  test('non-percentage charts use metric-aware ranges and labels', () {
    final samples = [
      TelemetrySample(timestamp: DateTime(2026, 6, 20), value: 4.5),
    ];

    expect(
      telemetryChartMaxY(samples, TelemetryMetricKind.gigahertz),
      greaterThan(4.5),
    );
    expect(
      formatTelemetryValue(4.25, TelemetryMetricKind.gigahertz),
      '4.25 GHz',
    );
    expect(formatTelemetryValue(72, TelemetryMetricKind.temperature), '72°C');
  });
}
