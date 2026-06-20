enum StorageHealth { healthy, warning, critical }

StorageHealth storageHealthFromString(String? value) {
  return switch (value?.toLowerCase()) {
    'critical' => StorageHealth.critical,
    'warning' => StorageHealth.warning,
    _ => StorageHealth.healthy,
  };
}

class StorageInsight {
  final StorageHealth severity;
  final String title;
  final String message;

  const StorageInsight({
    required this.severity,
    required this.title,
    required this.message,
  });

  factory StorageInsight.fromJson(Map<String, dynamic> json) {
    return StorageInsight(
      severity: storageHealthFromString(json['severity']?.toString()),
      title: json['title']?.toString() ?? 'Storage insight',
      message: json['message']?.toString() ?? 'No additional details.',
    );
  }
}

class StorageDrive {
  final String id;
  final String mountPoint;
  final String label;
  final String filesystem;
  final String device;
  final String model;
  final String? serial;
  final String interfaceType;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final double usedPercent;
  final double readBps;
  final double writeBps;
  final double? temperatureC;
  final StorageHealth health;
  final String? smartStatus;
  final bool removable;
  final int score;
  final List<StorageInsight> insights;

  const StorageDrive({
    required this.id,
    required this.mountPoint,
    required this.label,
    required this.filesystem,
    required this.device,
    required this.model,
    required this.serial,
    required this.interfaceType,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.usedPercent,
    required this.readBps,
    required this.writeBps,
    required this.temperatureC,
    required this.health,
    required this.smartStatus,
    required this.removable,
    required this.score,
    required this.insights,
  });

  String get displayName => label.trim().isEmpty ? mountPoint : label;

  factory StorageDrive.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'] as List<dynamic>? ?? const [];
    return StorageDrive(
      id: json['id']?.toString() ?? '',
      mountPoint: json['mount_point']?.toString() ?? 'Unavailable',
      label: json['label']?.toString() ?? '',
      filesystem: json['filesystem']?.toString() ?? 'Unavailable',
      device: json['device']?.toString() ?? 'Unavailable',
      model: json['model']?.toString() ?? 'Unavailable',
      serial: json['serial']?.toString(),
      interfaceType: json['interface_type']?.toString() ?? 'Unavailable',
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usedPercent: (json['used_percent'] as num?)?.toDouble() ?? 0,
      readBps: (json['read_bps'] as num?)?.toDouble() ?? 0,
      writeBps: (json['write_bps'] as num?)?.toDouble() ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      health: storageHealthFromString(json['health_status']?.toString()),
      smartStatus: json['smart_status']?.toString(),
      removable: json['removable'] == true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      insights: rawInsights
          .whereType<Map>()
          .map(
            (item) => StorageInsight.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class StorageSnapshot {
  final DateTime sampledAt;
  final int totalCapacity;
  final int usedCapacity;
  final int freeCapacity;
  final double usedPercent;
  final double readBps;
  final double writeBps;
  final double peakReadBps;
  final double peakWriteBps;
  final double? temperatureC;
  final StorageHealth health;
  final int storageScore;
  final List<StorageInsight> insights;
  final List<StorageDrive> drives;

  const StorageSnapshot({
    required this.sampledAt,
    required this.totalCapacity,
    required this.usedCapacity,
    required this.freeCapacity,
    required this.usedPercent,
    required this.readBps,
    required this.writeBps,
    required this.peakReadBps,
    required this.peakWriteBps,
    required this.temperatureC,
    required this.health,
    required this.storageScore,
    required this.insights,
    required this.drives,
  });

  factory StorageSnapshot.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'] as List<dynamic>? ?? const [];
    final rawDrives = json['drives'] as List<dynamic>? ?? const [];
    return StorageSnapshot(
      sampledAt:
          DateTime.tryParse(json['sampled_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      usedCapacity: (json['used_capacity'] as num?)?.toInt() ?? 0,
      freeCapacity: (json['free_capacity'] as num?)?.toInt() ?? 0,
      usedPercent: (json['used_percent'] as num?)?.toDouble() ?? 0,
      readBps: (json['read_bps'] as num?)?.toDouble() ?? 0,
      writeBps: (json['write_bps'] as num?)?.toDouble() ?? 0,
      peakReadBps: (json['peak_read_bps'] as num?)?.toDouble() ?? 0,
      peakWriteBps: (json['peak_write_bps'] as num?)?.toDouble() ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      health: storageHealthFromString(json['health_status']?.toString()),
      storageScore: (json['storage_score'] as num?)?.toInt() ?? 0,
      insights: rawInsights
          .whereType<Map>()
          .map(
            (item) => StorageInsight.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      drives: rawDrives
          .whereType<Map>()
          .map((item) => StorageDrive.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}

class StorageHistorySample {
  final DateTime timestamp;
  final double capacityPercent;
  final double readBps;
  final double writeBps;
  final double? temperatureC;

  const StorageHistorySample({
    required this.timestamp,
    required this.capacityPercent,
    required this.readBps,
    required this.writeBps,
    required this.temperatureC,
  });

  factory StorageHistorySample.fromJson(Map<String, dynamic> json) {
    return StorageHistorySample(
      timestamp:
          DateTime.tryParse('${json['timestamp']}Z')?.toLocal() ??
          DateTime.now(),
      capacityPercent: (json['capacity_percent'] as num?)?.toDouble() ?? 0,
      readBps: (json['read_bps'] as num?)?.toDouble() ?? 0,
      writeBps: (json['write_bps'] as num?)?.toDouble() ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
    );
  }
}

class StorageHeatmapCell {
  final int weekday;
  final int hour;
  final double throughputBps;

  const StorageHeatmapCell({
    required this.weekday,
    required this.hour,
    required this.throughputBps,
  });

  factory StorageHeatmapCell.fromJson(Map<String, dynamic> json) {
    return StorageHeatmapCell(
      weekday: (json['weekday'] as num?)?.toInt() ?? 0,
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      throughputBps: (json['throughput_bps'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StorageForecast {
  final double? daysUntilFull;
  final double confidence;
  final double trendPerDay;

  const StorageForecast({
    required this.daysUntilFull,
    required this.confidence,
    required this.trendPerDay,
  });

  factory StorageForecast.fromJson(Map<String, dynamic> json) {
    return StorageForecast(
      daysUntilFull: (json['days_until_full'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      trendPerDay: (json['trend_per_day'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StorageHistory {
  final List<StorageHistorySample> samples;
  final List<StorageHeatmapCell> heatmap;
  final StorageForecast? forecast;

  const StorageHistory({
    required this.samples,
    required this.heatmap,
    required this.forecast,
  });

  factory StorageHistory.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] as List<dynamic>? ?? const [];
    final rawHeatmap = json['heatmap'] as List<dynamic>? ?? const [];
    final rawForecast = json['forecast'];
    return StorageHistory(
      samples: rawSamples
          .whereType<Map>()
          .map(
            (item) =>
                StorageHistorySample.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      heatmap: rawHeatmap
          .whereType<Map>()
          .map(
            (item) =>
                StorageHeatmapCell.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      forecast: rawForecast is Map
          ? StorageForecast.fromJson(Map<String, dynamic>.from(rawForecast))
          : null,
    );
  }
}

class StorageUsageNode {
  final String name;
  final String path;
  final int sizeBytes;
  final double percentOfDisk;
  final List<StorageUsageNode> children;

  const StorageUsageNode({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.percentOfDisk,
    required this.children,
  });

  factory StorageUsageNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>? ?? const [];
    return StorageUsageNode(
      name: json['name']?.toString() ?? 'Unknown',
      path: json['path']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      percentOfDisk: (json['percent_of_disk'] as num?)?.toDouble() ?? 0,
      children: rawChildren
          .whereType<Map>()
          .map(
            (item) =>
                StorageUsageNode.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class StorageUsageFile {
  final String name;
  final String path;
  final int sizeBytes;
  final double percentOfDisk;

  const StorageUsageFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.percentOfDisk,
  });

  factory StorageUsageFile.fromJson(Map<String, dynamic> json) {
    return StorageUsageFile(
      name: json['name']?.toString() ?? 'Unknown',
      path: json['path']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      percentOfDisk: (json['percent_of_disk'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StorageScanJob {
  final String id;
  final String status;
  final double progress;
  final int scannedBytes;
  final int scannedFiles;
  final String? currentPath;
  final String? error;
  final List<StorageUsageNode> tree;
  final List<StorageUsageFile> largestFiles;

  const StorageScanJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.scannedBytes,
    required this.scannedFiles,
    required this.currentPath,
    required this.error,
    required this.tree,
    required this.largestFiles,
  });

  bool get isFinished => status == 'complete' || status == 'failed';

  factory StorageScanJob.fromJson(Map<String, dynamic> json) {
    final rawTree = json['tree'] as List<dynamic>? ?? const [];
    final rawFiles = json['largest_files'] as List<dynamic>? ?? const [];
    return StorageScanJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'running',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      scannedBytes: (json['scanned_bytes'] as num?)?.toInt() ?? 0,
      scannedFiles: (json['scanned_files'] as num?)?.toInt() ?? 0,
      currentPath: json['current_path']?.toString(),
      error: json['error']?.toString(),
      tree: rawTree
          .whereType<Map>()
          .map(
            (item) =>
                StorageUsageNode.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      largestFiles: rawFiles
          .whereType<Map>()
          .map(
            (item) =>
                StorageUsageFile.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class StorageBenchmarkResults {
  final double sequentialReadMbps;
  final double sequentialWriteMbps;
  final double randomReadMbps;
  final double randomWriteMbps;

  const StorageBenchmarkResults({
    required this.sequentialReadMbps,
    required this.sequentialWriteMbps,
    required this.randomReadMbps,
    required this.randomWriteMbps,
  });

  factory StorageBenchmarkResults.fromJson(Map<String, dynamic> json) {
    return StorageBenchmarkResults(
      sequentialReadMbps:
          (json['sequential_read_mbps'] as num?)?.toDouble() ?? 0,
      sequentialWriteMbps:
          (json['sequential_write_mbps'] as num?)?.toDouble() ?? 0,
      randomReadMbps: (json['random_read_mbps'] as num?)?.toDouble() ?? 0,
      randomWriteMbps: (json['random_write_mbps'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StorageBenchmarkJob {
  final String id;
  final String status;
  final String mode;
  final double progress;
  final String? error;
  final StorageBenchmarkResults? results;

  const StorageBenchmarkJob({
    required this.id,
    required this.status,
    required this.mode,
    required this.progress,
    required this.error,
    required this.results,
  });

  bool get isFinished => status == 'complete' || status == 'failed';

  factory StorageBenchmarkJob.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return StorageBenchmarkJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'running',
      mode: json['mode']?.toString() ?? 'quick',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      error: json['error']?.toString(),
      results: rawResults is Map
          ? StorageBenchmarkResults.fromJson(
              Map<String, dynamic>.from(rawResults),
            )
          : null,
    );
  }
}
