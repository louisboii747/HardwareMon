enum BenchmarkComparisonFilter {
  identicalCpu,
  identicalCpuAndGpu,
  cpuFamily,
  platform,
  allResults,
}

extension BenchmarkComparisonFilterLabel on BenchmarkComparisonFilter {
  String get label => switch (this) {
    BenchmarkComparisonFilter.identicalCpu => 'Identical CPU',
    BenchmarkComparisonFilter.identicalCpuAndGpu => 'CPU + GPU',
    BenchmarkComparisonFilter.cpuFamily => 'CPU family',
    BenchmarkComparisonFilter.platform => 'Platform',
    BenchmarkComparisonFilter.allResults => 'All results',
  };
}

class BenchmarkComparison {
  final bool available;
  final String sourceLabel;
  final bool offlineFallback;
  final BenchmarkComparisonFilter filter;
  final int sampleSize;
  final double percentile;
  final double averageScore;
  final double? averageIdenticalCpu;
  final double? averageIdenticalCpuAndGpu;
  final int topTenScore;
  final int highestScore;
  final double medianScore;
  final int lowestScore;
  final List<String> insights;
  final String? unavailableReason;

  const BenchmarkComparison({
    required this.available,
    required this.sourceLabel,
    required this.offlineFallback,
    required this.filter,
    required this.sampleSize,
    required this.percentile,
    required this.averageScore,
    required this.averageIdenticalCpu,
    required this.averageIdenticalCpuAndGpu,
    required this.topTenScore,
    required this.highestScore,
    required this.medianScore,
    required this.lowestScore,
    required this.insights,
    required this.unavailableReason,
  });

  const BenchmarkComparison.unavailable({
    required this.sourceLabel,
    required this.filter,
    required String reason,
  }) : available = false,
       offlineFallback = false,
       sampleSize = 0,
       percentile = 0,
       averageScore = 0,
       averageIdenticalCpu = null,
       averageIdenticalCpuAndGpu = null,
       topTenScore = 0,
       highestScore = 0,
       medianScore = 0,
       lowestScore = 0,
       insights = const [],
       unavailableReason = reason;
}

enum BenchmarkSubmissionStatus { submitted, unavailable, failed }

class BenchmarkSubmissionOutcome {
  final BenchmarkSubmissionStatus status;
  final String message;

  const BenchmarkSubmissionOutcome(this.status, this.message);
}
