import 'dart:math' as math;

import '../models/benchmark_comparison.dart';
import '../models/benchmark_models.dart';

abstract class BenchmarkComparisonProvider {
  String get name;
  bool get isRemote;
  bool get isAvailable;

  Future<BenchmarkComparison> compare({
    required BenchmarkResult result,
    required List<BenchmarkResult> results,
    required BenchmarkComparisonFilter filter,
  });

  Future<BenchmarkSubmissionOutcome> submitAnonymously(BenchmarkResult result);
}

class LocalBenchmarkComparisonProvider implements BenchmarkComparisonProvider {
  @override
  String get name => 'Local history';

  @override
  bool get isRemote => false;

  @override
  bool get isAvailable => true;

  @override
  Future<BenchmarkComparison> compare({
    required BenchmarkResult result,
    required List<BenchmarkResult> results,
    required BenchmarkComparisonFilter filter,
  }) async {
    final versionCompatible = results
        .where((item) => item.benchmarkVersion == result.benchmarkVersion)
        .toList(growable: false);
    final matching = versionCompatible
        .where((item) => _matches(item, result, filter))
        .toList(growable: false);
    if (matching.isEmpty) {
      return BenchmarkComparison.unavailable(
        sourceLabel: name,
        filter: filter,
        reason: 'No version-compatible local results match this filter yet.',
      );
    }

    final scores = matching.map((item) => item.overallScore).toList()..sort();
    final cpuMatches = versionCompatible.where(
      (item) => _canonical(item.cpuModel) == _canonical(result.cpuModel),
    );
    final cpuGpuMatches = cpuMatches.where(
      (item) =>
          _knownGpu(result.gpuModel) &&
          _canonical(item.gpuModel ?? '') == _canonical(result.gpuModel ?? ''),
    );
    final averages = _componentAverages(matching);
    final percentile =
        scores.where((score) => score < result.overallScore).length /
        scores.length *
        100;

    return BenchmarkComparison(
      available: true,
      sourceLabel: name,
      offlineFallback: true,
      filter: filter,
      sampleSize: matching.length,
      percentile: percentile,
      averageScore: _average(scores),
      averageIdenticalCpu: _resultAverage(cpuMatches),
      averageIdenticalCpuAndGpu: _resultAverage(cpuGpuMatches),
      topTenScore: _percentile(scores, 0.90),
      highestScore: scores.last,
      medianScore: _median(scores),
      lowestScore: scores.first,
      insights: _insights(result, averages, _median(scores), matching.length),
      unavailableReason: null,
    );
  }

  @override
  Future<BenchmarkSubmissionOutcome> submitAnonymously(
    BenchmarkResult result,
  ) async {
    return const BenchmarkSubmissionOutcome(
      BenchmarkSubmissionStatus.unavailable,
      'Local comparison never uploads benchmark data.',
    );
  }
}

/// Future HardwareMon cloud adapter.
///
/// This placeholder performs no network request. A production implementation
/// can map [BenchmarkResult.toAnonymousSubmissionJson] to the documented cloud
/// API after explicit consent, without changing the page or local provider.
class PlaceholderRemoteBenchmarkComparisonProvider
    implements BenchmarkComparisonProvider {
  final Uri? endpoint;
  final bool enabled;

  const PlaceholderRemoteBenchmarkComparisonProvider({
    this.endpoint,
    this.enabled = false,
  });

  @override
  String get name => 'HardwareMon Cloud';

  @override
  bool get isRemote => true;

  @override
  bool get isAvailable => enabled && endpoint != null;

  @override
  Future<BenchmarkComparison> compare({
    required BenchmarkResult result,
    required List<BenchmarkResult> results,
    required BenchmarkComparisonFilter filter,
  }) async {
    return BenchmarkComparison.unavailable(
      sourceLabel: name,
      filter: filter,
      reason: 'Online comparisons are not connected in this release.',
    );
  }

  @override
  Future<BenchmarkSubmissionOutcome> submitAnonymously(
    BenchmarkResult result,
  ) async {
    // Build the future payload now to keep privacy exclusions testable, but do
    // not transmit it until a real cloud provider is configured.
    result.toAnonymousSubmissionJson();
    return const BenchmarkSubmissionOutcome(
      BenchmarkSubmissionStatus.unavailable,
      'Cloud submission is not enabled yet. Your result remains local.',
    );
  }
}

class BenchmarkComparisonCoordinator {
  final BenchmarkComparisonProvider local;
  final BenchmarkComparisonProvider remote;

  BenchmarkComparisonCoordinator({
    BenchmarkComparisonProvider? local,
    BenchmarkComparisonProvider? remote,
  }) : local = local ?? LocalBenchmarkComparisonProvider(),
       remote = remote ?? const PlaceholderRemoteBenchmarkComparisonProvider();

  Future<BenchmarkComparison> compare({
    required BenchmarkResult result,
    required List<BenchmarkResult> results,
    required BenchmarkComparisonFilter filter,
  }) async {
    if (remote.isAvailable) {
      try {
        final online = await remote.compare(
          result: result,
          results: results,
          filter: filter,
        );
        if (online.available) return online;
      } catch (_) {
        // Connectivity and service failures always degrade to local history.
      }
    }
    return local.compare(result: result, results: results, filter: filter);
  }

  Future<BenchmarkSubmissionOutcome> submitAnonymously(BenchmarkResult result) {
    return remote.submitAnonymously(result);
  }
}

bool _matches(
  BenchmarkResult candidate,
  BenchmarkResult target,
  BenchmarkComparisonFilter filter,
) {
  return switch (filter) {
    BenchmarkComparisonFilter.identicalCpu =>
      _canonical(candidate.cpuModel) == _canonical(target.cpuModel),
    BenchmarkComparisonFilter.identicalCpuAndGpu =>
      _knownGpu(target.gpuModel) &&
          _canonical(candidate.cpuModel) == _canonical(target.cpuModel) &&
          _canonical(candidate.gpuModel ?? '') ==
              _canonical(target.gpuModel ?? ''),
    BenchmarkComparisonFilter.cpuFamily =>
      _cpuFamily(candidate.cpuModel) == _cpuFamily(target.cpuModel),
    BenchmarkComparisonFilter.platform =>
      _canonical(candidate.operatingSystem) ==
          _canonical(target.operatingSystem),
    BenchmarkComparisonFilter.allResults => true,
  };
}

String _canonical(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\(r\)|\(tm\)|\bcpu\b'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _cpuFamily(String model) {
  final value = _canonical(model).split('@').first.trim();
  final patterns = [
    RegExp(r'(intel\s+core\s+ultra\s+[3579])'),
    RegExp(r'(intel\s+core\s+i[3579])'),
    RegExp(r'(amd\s+ryzen\s+[3579])'),
    RegExp(r'(apple\s+m\d+)'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(value);
    if (match != null) return match.group(1)!;
  }
  return value.split(RegExp(r'\s+')).take(3).join(' ');
}

bool _knownGpu(String? value) {
  final gpu = _canonical(value ?? '');
  return gpu.isNotEmpty && gpu != 'unknown' && gpu != 'unknown gpu';
}

double _average(Iterable<int> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 0;
  return list.reduce((left, right) => left + right) / list.length;
}

double? _resultAverage(Iterable<BenchmarkResult> results) {
  final scores = results.map((item) => item.overallScore).toList();
  return scores.isEmpty ? null : _average(scores);
}

double _median(List<int> sorted) {
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle].toDouble();
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

int _percentile(List<int> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index.clamp(0, sorted.length - 1)];
}

Map<String, double> _componentAverages(List<BenchmarkResult> results) {
  return {
    'cpu': _average(results.map((item) => item.cpuScore)),
    'memory': _average(results.map((item) => item.memoryScore)),
    'disk': _average(results.map((item) => item.diskScore)),
  };
}

List<String> _insights(
  BenchmarkResult result,
  Map<String, double> averages,
  double median,
  int sampleSize,
) {
  if (sampleSize < 2) {
    return const [
      'Run the benchmark again under similar conditions to build a useful local baseline.',
    ];
  }
  final insights = <String>[];
  _componentInsight(insights, 'CPU', result.cpuScore, averages['cpu']!);
  _componentInsight(
    insights,
    'Memory',
    result.memoryScore,
    averages['memory']!,
  );

  final diskRatio = result.diskScore / math.max(1, averages['disk']!);
  if (diskRatio >= 1.12) {
    insights.add(
      'Disk speed is excellent for the ${result.storageType ?? 'detected storage'} comparison set.',
    );
  } else if (diskRatio < 0.88) {
    insights.add(
      'Disk performance is lower than expected for comparable runs.',
    );
  }

  final cpuRatio = result.cpuScore / math.max(1, averages['cpu']!);
  final memoryRatio = result.memoryScore / math.max(1, averages['memory']!);
  if (result.overallScore < median * 0.86 && cpuRatio < 0.86) {
    insights.add(
      'This run may have been affected by thermal throttling or a restrictive power mode.',
    );
  } else if (memoryRatio < 0.88 && cpuRatio >= 0.92) {
    insights.add(
      'Background applications may have affected memory performance during this run.',
    );
  }
  return insights.isEmpty
      ? const ['Performance is consistent with the selected comparison set.']
      : insights;
}

void _componentInsight(
  List<String> insights,
  String name,
  int score,
  double average,
) {
  final ratio = score / math.max(1, average);
  if (ratio >= 1.08) {
    insights.add('$name performs above average.');
  } else if (ratio < 0.90) {
    insights.add('$name performance is lower than expected.');
  }
}
