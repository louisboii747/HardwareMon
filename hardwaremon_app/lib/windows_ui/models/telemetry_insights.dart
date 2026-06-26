import 'dart:math' as math;

import 'telemetry_sample.dart';
import 'telemetry_statistics.dart';

enum TelemetryInsightSeverity { healthy, info, warning, critical }

class TelemetryInsight {
  final TelemetryInsightSeverity severity;
  final String title;
  final String detail;

  const TelemetryInsight({
    required this.severity,
    required this.title,
    required this.detail,
  });
}

class TelemetrySessionSummary {
  final int score;
  final String headline;
  final String detail;
  final double cpuAverage;
  final double cpuPeak;
  final double ramAverage;
  final double ramPeak;
  final double gpuAverage;
  final double gpuPeak;
  final double cpuTemperaturePeak;
  final double gpuTemperaturePeak;
  final double memoryHeadroom;
  final double thermalHeadroom;
  final int sampleCount;
  final List<TelemetryInsight> insights;

  const TelemetrySessionSummary({
    required this.score,
    required this.headline,
    required this.detail,
    required this.cpuAverage,
    required this.cpuPeak,
    required this.ramAverage,
    required this.ramPeak,
    required this.gpuAverage,
    required this.gpuPeak,
    required this.cpuTemperaturePeak,
    required this.gpuTemperaturePeak,
    required this.memoryHeadroom,
    required this.thermalHeadroom,
    required this.sampleCount,
    required this.insights,
  });
}

TelemetrySessionSummary buildTelemetrySessionSummary({
  required int cpuUsage,
  required int ramUsage,
  required int gpuUsage,
  required int cpuTemperature,
  required int gpuTemperature,
  required List<TelemetrySample> cpuHistory,
  required List<TelemetrySample> ramHistory,
  required List<TelemetrySample> gpuHistory,
  required List<TelemetrySample> cpuTemperatureHistory,
  required List<TelemetrySample> gpuTemperatureHistory,
  DateTime? since,
  bool paused = false,
  String? lastError,
}) {
  final cpuStats = calculateTelemetryStatistics(cpuHistory, since: since);
  final ramStats = calculateTelemetryStatistics(ramHistory, since: since);
  final gpuStats = calculateTelemetryStatistics(gpuHistory, since: since);
  final cpuTempStats = _positiveStatistics(
    cpuTemperatureHistory,
    fallback: cpuTemperature.toDouble(),
    since: since,
  );
  final gpuTempStats = _positiveStatistics(
    gpuTemperatureHistory,
    fallback: gpuTemperature.toDouble(),
    since: since,
  );

  final sampleCount = [
    cpuStats.sampleCount,
    ramStats.sampleCount,
    gpuStats.sampleCount,
  ].reduce(math.max);

  final busyPeak = [
    cpuStats.maximum,
    ramStats.maximum,
    gpuStats.maximum,
    cpuUsage.toDouble(),
    ramUsage.toDouble(),
    gpuUsage.toDouble(),
  ].reduce(math.max);
  final hottestPeak = [
    cpuTempStats.maximum,
    gpuTempStats.maximum,
    cpuTemperature.toDouble(),
    gpuTemperature.toDouble(),
  ].where((value) => value > 0).fold<double>(0, math.max);
  final busiestAverage = [
    _averageOrFallback(cpuStats, cpuUsage.toDouble()),
    _averageOrFallback(ramStats, ramUsage.toDouble()),
    _averageOrFallback(gpuStats, gpuUsage.toDouble()),
  ].reduce(math.max);

  final pressurePenalty = math.max(0, busyPeak - 70) * 0.42;
  final sustainedPenalty = math.max(0, busiestAverage - 55) * 0.28;
  final thermalPenalty = math.max(0, hottestPeak - 70) * 0.74;
  final errorPenalty = lastError == null ? 0 : 28;
  final pausePenalty = paused ? 4 : 0;
  final score =
      (100 -
              pressurePenalty -
              sustainedPenalty -
              thermalPenalty -
              errorPenalty -
              pausePenalty)
          .round()
          .clamp(0, 100);

  final insights = <TelemetryInsight>[];
  if (lastError != null) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.critical,
        title: 'Telemetry link needs attention',
        detail:
            'The live backend did not answer the latest request. Refresh or export diagnostics if the issue persists.',
      ),
    );
  }
  if (sampleCount < 6) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.info,
        title: 'Building a baseline',
        detail:
            'Keep monitoring open for a few more samples to sharpen trends, peaks, and recommendations.',
      ),
    );
  }
  if (busyPeak >= 94) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.critical,
        title: 'Resource ceiling reached',
        detail:
            'One or more workload metrics recently hit the top of the scale. Check Processes for the active offender.',
      ),
    );
  } else if (busiestAverage >= 72) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.warning,
        title: 'Sustained workload pressure',
        detail:
            'Average load is elevated across the current session. Watch for stutter, fan ramp, or slow app launches.',
      ),
    );
  }
  if (ramStats.maximum >= 88 || ramUsage >= 88) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.warning,
        title: 'Memory headroom is thin',
        detail:
            'Memory usage is close to the alert zone. Sort Processes by memory before starting another heavy app.',
      ),
    );
  }
  if (hottestPeak >= 88) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.critical,
        title: 'Thermal ceiling is close',
        detail:
            'A CPU or GPU temperature peak is high enough to deserve airflow, fan curve, or workload attention.',
      ),
    );
  } else if (hottestPeak >= 78) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.warning,
        title: 'Thermals are warming up',
        detail:
            'Temperatures are still usable, but there is less cooling headroom for long workloads.',
      ),
    );
  }
  if (paused) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.info,
        title: 'Telemetry is paused',
        detail:
            'The current view is frozen. Resume monitoring when you want fresh session analysis.',
      ),
    );
  }
  if (insights.isEmpty) {
    insights.add(
      const TelemetryInsight(
        severity: TelemetryInsightSeverity.healthy,
        title: 'Session looks healthy',
        detail:
            'No sustained pressure or thermal risk is visible in the current monitoring window.',
      ),
    );
  }

  return TelemetrySessionSummary(
    score: score,
    headline: _headlineForScore(score),
    detail: _detailForScore(score, sampleCount),
    cpuAverage: _averageOrFallback(cpuStats, cpuUsage.toDouble()),
    cpuPeak: math.max(cpuStats.maximum, cpuUsage.toDouble()),
    ramAverage: _averageOrFallback(ramStats, ramUsage.toDouble()),
    ramPeak: math.max(ramStats.maximum, ramUsage.toDouble()),
    gpuAverage: _averageOrFallback(gpuStats, gpuUsage.toDouble()),
    gpuPeak: math.max(gpuStats.maximum, gpuUsage.toDouble()),
    cpuTemperaturePeak: math.max(
      cpuTempStats.maximum,
      cpuTemperature.toDouble(),
    ),
    gpuTemperaturePeak: math.max(
      gpuTempStats.maximum,
      gpuTemperature.toDouble(),
    ),
    memoryHeadroom: math.max(
      0.0,
      100.0 - math.max(ramStats.current, ramUsage.toDouble()),
    ),
    thermalHeadroom: hottestPeak <= 0 ? 0.0 : math.max(0.0, 95.0 - hottestPeak),
    sampleCount: sampleCount,
    insights: insights,
  );
}

TelemetryStatistics _positiveStatistics(
  List<TelemetrySample> samples, {
  required double fallback,
  DateTime? since,
}) {
  final filtered = samples
      .where((sample) => sample.value > 0)
      .toList(growable: false);
  if (filtered.isEmpty && fallback > 0) {
    return TelemetryStatistics(
      current: fallback,
      minimum: fallback,
      maximum: fallback,
      average: fallback,
      delta: 0,
      sampleCount: 1,
    );
  }
  return calculateTelemetryStatistics(filtered, since: since);
}

double _averageOrFallback(TelemetryStatistics statistics, double fallback) {
  return statistics.sampleCount == 0 ? fallback : statistics.average;
}

String _headlineForScore(int score) {
  if (score >= 90) return 'Excellent headroom';
  if (score >= 78) return 'Healthy session';
  if (score >= 62) return 'Watchlist recommended';
  if (score >= 42) return 'Attention recommended';
  return 'Action recommended';
}

String _detailForScore(int score, int sampleCount) {
  if (sampleCount < 6) {
    return 'Collecting enough samples to calibrate this session.';
  }
  if (score >= 78) {
    return 'Current telemetry leaves useful workload and thermal headroom.';
  }
  if (score >= 62) {
    return 'The system is usable, but at least one metric is trending hot.';
  }
  return 'One or more metrics are close to a limit in this session.';
}
