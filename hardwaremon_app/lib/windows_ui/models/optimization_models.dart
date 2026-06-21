import 'dart:math' as math;

import 'storage_models.dart';
import 'telemetry_sample.dart';

enum OptimizationSeverity { info, warning, critical }

class StartupApplication {
  final String id;
  final String name;
  final String publisher;
  final String command;
  final String impact;
  final bool enabled;
  final bool canToggle;
  final String detail;

  const StartupApplication({
    required this.id,
    required this.name,
    required this.publisher,
    required this.command,
    required this.impact,
    required this.enabled,
    required this.canToggle,
    required this.detail,
  });

  factory StartupApplication.fromJson(Map<String, dynamic> json) {
    return StartupApplication(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown application',
      publisher: json['publisher']?.toString() ?? 'Unknown publisher',
      command: json['command']?.toString() ?? 'Unavailable',
      impact: json['impact']?.toString() ?? 'medium',
      enabled: json['enabled'] == true,
      canToggle: json['can_toggle'] == true,
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class TemporaryFileLocation {
  final String label;
  final String path;
  final int sizeBytes;
  final int fileCount;

  const TemporaryFileLocation({
    required this.label,
    required this.path,
    required this.sizeBytes,
    required this.fileCount,
  });

  factory TemporaryFileLocation.fromJson(Map<String, dynamic> json) {
    return TemporaryFileLocation(
      label: json['label']?.toString() ?? 'Temporary files',
      path: json['path']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class OptimizationSnapshot {
  final String platform;
  final int startupScore;
  final List<StartupApplication> startupApps;
  final int temporaryBytes;
  final int temporaryFileCount;
  final bool temporaryEstimateTruncated;
  final List<TemporaryFileLocation> temporaryLocations;
  final bool startupToggleSupported;
  final bool gamingModeSupported;
  final bool cleanupSupported;

  const OptimizationSnapshot({
    required this.platform,
    required this.startupScore,
    required this.startupApps,
    required this.temporaryBytes,
    required this.temporaryFileCount,
    required this.temporaryEstimateTruncated,
    required this.temporaryLocations,
    required this.startupToggleSupported,
    required this.gamingModeSupported,
    required this.cleanupSupported,
  });

  factory OptimizationSnapshot.fromJson(Map<String, dynamic> json) {
    final temporary = Map<String, dynamic>.from(
      json['temporary_files'] as Map? ?? const {},
    );
    final capabilities = Map<String, dynamic>.from(
      json['capabilities'] as Map? ?? const {},
    );
    return OptimizationSnapshot(
      platform: json['platform']?.toString() ?? 'Unknown',
      startupScore: (json['startup_score'] as num?)?.toInt() ?? 0,
      startupApps: (json['startup_apps'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                StartupApplication.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      temporaryBytes: (temporary['estimated_bytes'] as num?)?.toInt() ?? 0,
      temporaryFileCount: (temporary['file_count'] as num?)?.toInt() ?? 0,
      temporaryEstimateTruncated: temporary['truncated'] == true,
      temporaryLocations: (temporary['locations'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                TemporaryFileLocation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      startupToggleSupported: capabilities['startup_toggle'] == true,
      gamingModeSupported: capabilities['gaming_mode'] == true,
      cleanupSupported: capabilities['cleanup'] == true,
    );
  }
}

class OptimizationHealthScores {
  final int overall;
  final int performance;
  final int startup;
  final int storage;
  final int memory;
  final int thermal;

  const OptimizationHealthScores({
    required this.overall,
    required this.performance,
    required this.startup,
    required this.storage,
    required this.memory,
    required this.thermal,
  });

  static OptimizationHealthScores calculate({
    required int cpuUsage,
    required int ramUsage,
    required int cpuTemperature,
    required int gpuTemperature,
    required List<TelemetrySample> cpuHistory,
    required List<TelemetrySample> ramHistory,
    required List<TelemetrySample> cpuTemperatureHistory,
    required List<TelemetrySample> gpuTemperatureHistory,
    OptimizationSnapshot? optimization,
    StorageSnapshot? storage,
  }) {
    final averageCpu = sampleAverage(cpuHistory, fallback: cpuUsage.toDouble());
    final peakCpu = samplePeak(cpuHistory, fallback: cpuUsage.toDouble());
    final performance = _clampScore(
      100 - averageCpu * 0.55 - math.max(0, peakCpu - 85) * 0.8,
    );

    final averageRam = sampleAverage(ramHistory, fallback: ramUsage.toDouble());
    final peakRam = samplePeak(ramHistory, fallback: ramUsage.toDouble());
    final memory = _clampScore(
      100 - math.max(0, averageRam - 45) * 0.8 - math.max(0, peakRam - 80),
    );

    final cpuAverage = _positiveAverage(cpuTemperatureHistory, cpuTemperature);
    final gpuAverage = _positiveAverage(gpuTemperatureHistory, gpuTemperature);
    final hottest = math.max(
      samplePeak(cpuTemperatureHistory, fallback: cpuTemperature.toDouble()),
      samplePeak(gpuTemperatureHistory, fallback: gpuTemperature.toDouble()),
    );
    final thermalAvailable = cpuAverage > 0 || gpuAverage > 0 || hottest > 0;
    final thermal = thermalAvailable
        ? _clampScore(
            100 -
                math.max(0, math.max(cpuAverage, gpuAverage) - 55) * 1.2 -
                math.max(0, hottest - 82) * 1.8,
          )
        : 75;

    final startup = optimization?.startupScore ?? 70;
    final storageScore =
        storage?.storageScore ??
        _clampScore(100 - math.max(0, (storage?.usedPercent ?? 50) - 65) * 1.4);
    final scores = [performance, startup, storageScore, memory, thermal];
    final overall =
        (scores.reduce((left, right) => left + right) / scores.length).round();

    return OptimizationHealthScores(
      overall: overall,
      performance: performance,
      startup: startup,
      storage: storageScore,
      memory: memory,
      thermal: thermal,
    );
  }
}

class OptimizationRecommendation {
  final String id;
  final OptimizationSeverity severity;
  final String title;
  final String description;
  final String action;
  final String details;

  const OptimizationRecommendation({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    required this.action,
    required this.details,
  });
}

abstract class OptimizationRecommendationEngine {
  const OptimizationRecommendationEngine();

  List<OptimizationRecommendation> evaluate(
    OptimizationRecommendationContext context,
  );
}

class OptimizationRecommendationContext {
  final OptimizationSnapshot? optimization;
  final StorageSnapshot? storage;
  final double averageRam;
  final double peakRam;
  final double averageCpuTemperature;
  final double peakCpuTemperature;

  const OptimizationRecommendationContext({
    required this.optimization,
    required this.storage,
    required this.averageRam,
    required this.peakRam,
    required this.averageCpuTemperature,
    required this.peakCpuTemperature,
  });
}

class StartupRecommendationEngine extends OptimizationRecommendationEngine {
  const StartupRecommendationEngine();

  @override
  List<OptimizationRecommendation> evaluate(
    OptimizationRecommendationContext context,
  ) {
    final highImpact =
        context.optimization?.startupApps
            .where((app) => app.enabled && app.impact == 'high')
            .toList() ??
        const [];
    if (highImpact.isEmpty) return const [];
    return [
      OptimizationRecommendation(
        id: 'startup-impact',
        severity: highImpact.length >= 4
            ? OptimizationSeverity.critical
            : OptimizationSeverity.warning,
        title: 'High startup impact applications detected',
        description:
            '${highImpact.length} high-impact ${highImpact.length == 1 ? 'application starts' : 'applications start'} with your session.',
        action: 'Review startup applications',
        details:
            'Disabling software you do not need immediately after sign-in can shorten startup time and reduce background memory use. HardwareMon only changes per-user entries.',
      ),
    ];
  }
}

class StorageRecommendationEngine extends OptimizationRecommendationEngine {
  const StorageRecommendationEngine();

  @override
  List<OptimizationRecommendation> evaluate(
    OptimizationRecommendationContext context,
  ) {
    final recommendations = <OptimizationRecommendation>[];
    final temporaryBytes = context.optimization?.temporaryBytes ?? 0;
    if (temporaryBytes >= 1024 * 1024 * 1024) {
      recommendations.add(
        OptimizationRecommendation(
          id: 'temporary-files',
          severity: temporaryBytes >= 5 * 1024 * 1024 * 1024
              ? OptimizationSeverity.critical
              : OptimizationSeverity.warning,
          title: 'Temporary files are consuming significant storage',
          description:
              '${formatByteSize(temporaryBytes)} of temporary or cache data was found.',
          action: 'Review cleanup opportunities',
          details:
              'The estimate covers standard temporary and cache locations. Cleanup remains a guided action because applications may still be using some files.',
        ),
      );
    }
    final usage = context.storage?.usedPercent ?? 0;
    if (usage >= 85) {
      recommendations.add(
        OptimizationRecommendation(
          id: 'storage-capacity',
          severity: usage >= 95
              ? OptimizationSeverity.critical
              : OptimizationSeverity.warning,
          title: 'SSD nearing capacity',
          description: '${usage.toStringAsFixed(0)}% of storage is in use.',
          action: 'Open Storage analysis',
          details:
              'Keeping free space available supports updates, temporary workloads, and SSD wear levelling. Inspect large directories before deleting data.',
        ),
      );
    }
    return recommendations;
  }
}

class MemoryRecommendationEngine extends OptimizationRecommendationEngine {
  const MemoryRecommendationEngine();

  @override
  List<OptimizationRecommendation> evaluate(
    OptimizationRecommendationContext context,
  ) {
    if (context.averageRam < 80 && context.peakRam < 90) return const [];
    return [
      OptimizationRecommendation(
        id: 'memory-pressure',
        severity: context.averageRam >= 88
            ? OptimizationSeverity.critical
            : OptimizationSeverity.warning,
        title: 'RAM usage frequently exceeds 80%',
        description:
            'Average ${context.averageRam.toStringAsFixed(0)}% · Peak ${context.peakRam.toStringAsFixed(0)}%.',
        action: 'Inspect memory-heavy processes',
        details:
            'Sustained memory pressure can increase paging and make application switching feel sluggish. Review the Processes page before closing important work.',
      ),
    ];
  }
}

class ThermalRecommendationEngine extends OptimizationRecommendationEngine {
  const ThermalRecommendationEngine();

  @override
  List<OptimizationRecommendation> evaluate(
    OptimizationRecommendationContext context,
  ) {
    if (context.peakCpuTemperature <= 0 ||
        (context.averageCpuTemperature < 75 &&
            context.peakCpuTemperature < 85)) {
      return const [];
    }
    return [
      OptimizationRecommendation(
        id: 'cpu-temperature',
        severity: context.peakCpuTemperature >= 95
            ? OptimizationSeverity.critical
            : OptimizationSeverity.warning,
        title: 'CPU temperatures exceed recommended levels',
        description:
            'Average ${context.averageCpuTemperature.toStringAsFixed(0)}°C · Peak ${context.peakCpuTemperature.toStringAsFixed(0)}°C.',
        action: 'Review cooling and workloads',
        details:
            'Check airflow, fan operation, dust build-up, and sustained background workloads. Temperature limits vary by processor, so use this as a prompt for inspection rather than a hardware diagnosis.',
      ),
    ];
  }
}

List<OptimizationRecommendation> buildOptimizationRecommendations(
  OptimizationRecommendationContext context, {
  List<OptimizationRecommendationEngine> engines = const [
    StartupRecommendationEngine(),
    StorageRecommendationEngine(),
    MemoryRecommendationEngine(),
    ThermalRecommendationEngine(),
  ],
}) {
  return [
    for (final engine in engines) ...engine.evaluate(context),
  ]..sort((left, right) => right.severity.index.compareTo(left.severity.index));
}

double sampleAverage(
  List<TelemetrySample> samples, {
  required double fallback,
}) {
  if (samples.isEmpty) return fallback;
  return samples.map((sample) => sample.value).reduce((a, b) => a + b) /
      samples.length;
}

double samplePeak(List<TelemetrySample> samples, {required double fallback}) {
  if (samples.isEmpty) return fallback;
  return samples.map((sample) => sample.value).fold<double>(fallback, math.max);
}

double _positiveAverage(List<TelemetrySample> samples, int fallback) {
  final positive = samples.where((sample) => sample.value > 0).toList();
  if (positive.isEmpty) return fallback.toDouble();
  return sampleAverage(positive, fallback: fallback.toDouble());
}

int _clampScore(num score) => score.round().clamp(0, 100);

String formatByteSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit <= 1 ? 0 : 1)} ${units[unit]}';
}
