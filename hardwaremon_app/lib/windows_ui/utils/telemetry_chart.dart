import 'dart:math' as math;

import '../models/telemetry_sample.dart';

enum TelemetryMetricKind {
  percentage,
  temperature,
  gigahertz,
  watts,
  gigabytes,
}

String formatTelemetryValue(double value, TelemetryMetricKind kind) {
  return switch (kind) {
    TelemetryMetricKind.percentage => '${value.round()}%',
    TelemetryMetricKind.temperature => '${value.round()}°C',
    TelemetryMetricKind.gigahertz => '${value.toStringAsFixed(2)} GHz',
    TelemetryMetricKind.watts => '${value.toStringAsFixed(1)} W',
    TelemetryMetricKind.gigabytes => '${value.toStringAsFixed(1)} GB',
  };
}

double telemetryChartMaxY(
  List<TelemetrySample> samples,
  TelemetryMetricKind kind,
) {
  final peak = samples.isEmpty
      ? 0.0
      : samples
            .map((sample) => sample.value)
            .fold<double>(0, (current, value) => math.max(current, value));

  return switch (kind) {
    TelemetryMetricKind.percentage => math.max(100, peak * 1.08),
    TelemetryMetricKind.temperature => math.max(100, peak * 1.08),
    TelemetryMetricKind.gigahertz => math.max(1, peak * 1.18),
    TelemetryMetricKind.watts => math.max(10, peak * 1.18),
    TelemetryMetricKind.gigabytes => math.max(1, peak * 1.12),
  };
}
