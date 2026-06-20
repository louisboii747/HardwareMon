import 'dart:math' as math;

import 'telemetry_sample.dart';

class TelemetryStatistics {
  final double current;
  final double minimum;
  final double maximum;
  final double average;
  final double delta;
  final int sampleCount;

  const TelemetryStatistics({
    required this.current,
    required this.minimum,
    required this.maximum,
    required this.average,
    required this.delta,
    required this.sampleCount,
  });

  bool get isRising => delta > 0.05;
  bool get isFalling => delta < -0.05;
}

TelemetryStatistics calculateTelemetryStatistics(
  List<TelemetrySample> samples, {
  DateTime? since,
}) {
  final filtered = since == null
      ? samples
      : samples
            .where((sample) => !sample.timestamp.isBefore(since))
            .toList(growable: false);

  if (filtered.isEmpty) {
    return const TelemetryStatistics(
      current: 0,
      minimum: 0,
      maximum: 0,
      average: 0,
      delta: 0,
      sampleCount: 0,
    );
  }

  var minimum = filtered.first.value;
  var maximum = filtered.first.value;
  var sum = 0.0;

  for (final sample in filtered) {
    minimum = math.min(minimum, sample.value);
    maximum = math.max(maximum, sample.value);
    sum += sample.value;
  }

  final current = filtered.last.value;
  final previous = filtered.length > 1
      ? filtered[filtered.length - 2].value
      : current;

  return TelemetryStatistics(
    current: current,
    minimum: minimum,
    maximum: maximum,
    average: sum / filtered.length,
    delta: current - previous,
    sampleCount: filtered.length,
  );
}
