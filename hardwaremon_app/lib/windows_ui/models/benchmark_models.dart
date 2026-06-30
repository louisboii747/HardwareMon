enum BenchmarkRunState { idle, running, completed, failed, cancelled }

BenchmarkRunState benchmarkRunStateFromString(String? value) {
  return switch (value?.toLowerCase()) {
    'running' => BenchmarkRunState.running,
    'completed' => BenchmarkRunState.completed,
    'failed' => BenchmarkRunState.failed,
    'cancelled' => BenchmarkRunState.cancelled,
    _ => BenchmarkRunState.idle,
  };
}

class BenchmarkStatus {
  final BenchmarkRunState state;
  final String? runId;
  final String? currentTest;
  final double progress;
  final double elapsedTime;
  final String? errorMessage;
  final int? resultId;

  const BenchmarkStatus({
    required this.state,
    required this.runId,
    required this.currentTest,
    required this.progress,
    required this.elapsedTime,
    required this.errorMessage,
    required this.resultId,
  });

  const BenchmarkStatus.idle()
    : state = BenchmarkRunState.idle,
      runId = null,
      currentTest = null,
      progress = 0,
      elapsedTime = 0,
      errorMessage = null,
      resultId = null;

  bool get isRunning => state == BenchmarkRunState.running;
  bool get isTerminal => switch (state) {
    BenchmarkRunState.completed ||
    BenchmarkRunState.failed ||
    BenchmarkRunState.cancelled => true,
    _ => false,
  };

  factory BenchmarkStatus.fromJson(Map<String, dynamic> json) {
    return BenchmarkStatus(
      state: benchmarkRunStateFromString(json['status']?.toString()),
      runId: json['run_id']?.toString(),
      currentTest: json['current_test']?.toString(),
      progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100),
      elapsedTime: (json['elapsed_time'] as num?)?.toDouble() ?? 0,
      errorMessage: json['error_message']?.toString(),
      resultId: (json['result_id'] as num?)?.toInt(),
    );
  }
}

class BenchmarkResult {
  final int id;
  final DateTime timestamp;
  final String deviceName;
  final String platform;
  final String cpuModel;
  final int cpuCores;
  final int cpuThreads;
  final String? gpuModel;
  final int ramTotal;
  final int? ramSpeedMhz;
  final String? storageType;
  final String operatingSystem;
  final String benchmarkVersion;
  final int overallScore;
  final int cpuScore;
  final int memoryScore;
  final int diskScore;
  final double duration;
  final Map<String, dynamic> rawResult;

  const BenchmarkResult({
    required this.id,
    required this.timestamp,
    required this.deviceName,
    required this.platform,
    required this.cpuModel,
    required this.cpuCores,
    required this.cpuThreads,
    required this.gpuModel,
    required this.ramTotal,
    required this.ramSpeedMhz,
    required this.storageType,
    required this.operatingSystem,
    required this.benchmarkVersion,
    required this.overallScore,
    required this.cpuScore,
    required this.memoryScore,
    required this.diskScore,
    required this.duration,
    required this.rawResult,
  });

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    final raw = json['raw_result'];
    return BenchmarkResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deviceName: json['device_name']?.toString() ?? 'Unknown device',
      platform: json['platform']?.toString() ?? 'Unknown platform',
      cpuModel: json['cpu_model']?.toString() ?? 'Unknown CPU',
      cpuCores: (json['cpu_cores'] as num?)?.toInt() ?? 0,
      cpuThreads: (json['cpu_threads'] as num?)?.toInt() ?? 0,
      gpuModel: _optionalString(json['gpu_model']),
      ramTotal: (json['ram_total'] as num?)?.toInt() ?? 0,
      ramSpeedMhz: (json['ram_speed_mhz'] as num?)?.toInt(),
      storageType: _optionalString(json['storage_type']),
      operatingSystem:
          json['operating_system']?.toString() ??
          _operatingSystemFromPlatform(json['platform']?.toString()),
      benchmarkVersion: json['benchmark_version']?.toString() ?? 'Unknown',
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      cpuScore: (json['cpu_score'] as num?)?.toInt() ?? 0,
      memoryScore: (json['memory_score'] as num?)?.toInt() ?? 0,
      diskScore: (json['disk_score'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      rawResult: raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }

  /// Privacy-minimised payload for a future opt-in HardwareMon cloud service.
  /// Host/device names, serial numbers, network data, software, and files are
  /// deliberately excluded. Callers must still obtain explicit consent.
  Map<String, dynamic> toAnonymousSubmissionJson() {
    return {
      'schema_version': 1,
      'benchmark_version': benchmarkVersion,
      'hardware': {
        'cpu_model': cpuModel,
        'cpu_cores': cpuCores,
        'cpu_threads': cpuThreads,
        'gpu_model': gpuModel,
        'ram_total_bytes': ramTotal,
        'ram_speed_mhz': ramSpeedMhz,
        'storage_type': storageType,
        'operating_system': operatingSystem,
      },
      'scores': {
        'overall': overallScore,
        'cpu': cpuScore,
        'memory': memoryScore,
        'disk': diskScore,
      },
    };
  }
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'unknown') {
    return null;
  }
  return text;
}

String _operatingSystemFromPlatform(String? value) {
  final platform = value?.toLowerCase() ?? '';
  if (platform.contains('windows')) return 'Windows';
  if (platform.contains('darwin') || platform.contains('macos')) return 'macOS';
  if (platform.contains('linux')) return 'Linux';
  return 'Unknown';
}
