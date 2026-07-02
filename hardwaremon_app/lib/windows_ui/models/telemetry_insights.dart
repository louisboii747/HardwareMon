import 'dart:math' as math;

import 'telemetry_sample.dart';
import 'telemetry_statistics.dart';
import 'monitoring_lens.dart';

enum SystemHealthDimension { performance, memory, thermal, efficiency }

class SystemHealthSignal {
  final SystemHealthDimension dimension;
  final int score;
  final String label;
  final String detail;

  const SystemHealthSignal({
    required this.dimension,
    required this.score,
    required this.label,
    required this.detail,
  });
}

class SystemHealthProfile {
  final int overallScore;
  final String stateLabel;
  final String observation;
  final String bottleneck;
  final List<SystemHealthSignal> signals;

  const SystemHealthProfile({
    required this.overallScore,
    required this.stateLabel,
    required this.observation,
    required this.bottleneck,
    required this.signals,
  });
}

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

SystemHealthProfile buildSystemHealthProfile({
  required TelemetrySessionSummary summary,
  required int cpuUsage,
  required int ramUsage,
  required int gpuUsage,
  required int cpuTemperature,
  required int gpuTemperature,
  required double cpuPower,
  required double gpuPower,
  MonitoringLens lens = MonitoringLens.balanced,
  bool paused = false,
  bool hasError = false,
}) {
  final busiest = math.max(cpuUsage, gpuUsage);
  final hottest = math.max(cpuTemperature, gpuTemperature);
  final totalPower = math.max(0.0, cpuPower) + math.max(0.0, gpuPower);

  final performanceScore = _boundedScore(
    100 - math.max(0, busiest - 62) * 1.15,
  );
  final memoryScore = _boundedScore(100 - math.max(0, ramUsage - 52) * 1.25);
  final thermalScore = hottest <= 0
      ? 88
      : _boundedScore(100 - math.max(0, hottest - 55) * 1.55);
  final efficiencyScore = totalPower <= 0
      ? 86
      : _boundedScore(
          100 - math.max(0, totalPower - 75) * 0.28 - busiest * 0.08,
        );

  final reliabilityModifier = hasError
      ? -22
      : paused
      ? -4
      : 0;
  final weights = _lensWeights(lens);
  final overallScore = _boundedScore(
    performanceScore * weights.performance +
        memoryScore * weights.memory +
        thermalScore * weights.thermal +
        efficiencyScore * weights.efficiency +
        reliabilityModifier,
  );

  final pressures = <String, double>{
    'CPU': cpuUsage.toDouble(),
    'Memory': ramUsage.toDouble(),
    'GPU': gpuUsage.toDouble(),
    if (hottest > 0) 'Thermals': (hottest / 95 * 100).clamp(0, 100),
  };
  final bottleneckEntry = pressures.entries.reduce(
    (current, candidate) =>
        candidate.value > current.value ? candidate : current,
  );
  final bottleneck = bottleneckEntry.value < 58
      ? 'No active bottleneck'
      : '${bottleneckEntry.key} is carrying the most pressure';

  final observation = _systemObservation(
    summary: summary,
    cpuUsage: cpuUsage,
    ramUsage: ramUsage,
    gpuUsage: gpuUsage,
    hottest: hottest,
    paused: paused,
    hasError: hasError,
  );

  return SystemHealthProfile(
    overallScore: overallScore,
    stateLabel: _healthStateLabel(overallScore),
    observation: observation,
    bottleneck: bottleneck,
    signals: [
      SystemHealthSignal(
        dimension: SystemHealthDimension.performance,
        score: performanceScore,
        label: 'Performance',
        detail: busiest < 65 ? 'Responsive headroom' : 'Active workload',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.memory,
        score: memoryScore,
        label: 'Memory',
        detail: '${math.max(0, 100 - ramUsage)}% headroom',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.thermal,
        score: thermalScore,
        label: 'Thermals',
        detail: hottest <= 0 ? 'Awaiting sensors' : '$hottest°C peak now',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.efficiency,
        score: efficiencyScore,
        label: 'Efficiency',
        detail: totalPower <= 0
            ? 'Power baseline pending'
            : '${totalPower.toStringAsFixed(0)} W package draw',
      ),
    ],
  );
}

({double performance, double memory, double thermal, double efficiency})
_lensWeights(MonitoringLens lens) {
  return switch (lens) {
    MonitoringLens.balanced => (
      performance: 0.28,
      memory: 0.24,
      thermal: 0.30,
      efficiency: 0.18,
    ),
    MonitoringLens.performance => (
      performance: 0.44,
      memory: 0.20,
      thermal: 0.22,
      efficiency: 0.14,
    ),
    MonitoringLens.quiet => (
      performance: 0.14,
      memory: 0.18,
      thermal: 0.43,
      efficiency: 0.25,
    ),
    MonitoringLens.efficiency => (
      performance: 0.18,
      memory: 0.17,
      thermal: 0.24,
      efficiency: 0.41,
    ),
    MonitoringLens.reliability => (
      performance: 0.20,
      memory: 0.29,
      thermal: 0.35,
      efficiency: 0.16,
    ),
  };
}

int _boundedScore(num value) => value.round().clamp(0, 100);

String _healthStateLabel(int score) {
  if (score >= 90) return 'Exceptional';
  if (score >= 78) return 'Healthy';
  if (score >= 62) return 'Watch';
  if (score >= 42) return 'Stressed';
  return 'Critical';
}

String _systemObservation({
  required TelemetrySessionSummary summary,
  required int cpuUsage,
  required int ramUsage,
  required int gpuUsage,
  required int hottest,
  required bool paused,
  required bool hasError,
}) {
  if (hasError) {
    return 'Live telemetry was interrupted. HardwareMon is preserving the last known session context.';
  }
  if (paused) {
    return 'The session is paused, so scores and observations are frozen at the last sample.';
  }
  if (summary.sampleCount < 6) {
    return 'HardwareMon is learning this session. Trend confidence improves as new samples arrive.';
  }
  if (hottest >= 88) {
    return 'Thermal pressure is the clearest constraint right now. Cooling headroom deserves attention.';
  }
  if (ramUsage >= 88) {
    return 'Memory headroom is narrow. Opening another heavy application may increase paging.';
  }
  if (cpuUsage >= 90 || gpuUsage >= 90) {
    return 'A compute resource is close to saturation. Processes can identify the active workload.';
  }
  if (cpuUsage < 18 && gpuUsage < 18 && ramUsage < 65) {
    return 'The system is coasting with generous compute headroom and no immediate pressure.';
  }
  if (summary.cpuPeak - summary.cpuAverage < 8 &&
      summary.ramPeak - summary.ramAverage < 6) {
    return 'Workload behaviour is stable across the current session with limited volatility.';
  }
  return 'The system is balancing the current workload without a critical resource constraint.';
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
