class ProcessInfo {
  final int pid;
  final String name;
  final double cpu;
  final double ram;
  final bool isSystem;
  final String? username;
  final String? status;
  final double memoryPercent;
  final int? threadCount;
  final DateTime? startedAt;

  ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.ram,
    required this.isSystem,
    this.username,
    this.status,
    this.memoryPercent = 0,
    this.threadCount,
    this.startedAt,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] as int,
      name: json['name'] ?? 'Unknown',
      cpu: (json['cpu'] as num? ?? 0).toDouble(),
      ram: (json['ram'] as num? ?? 0).toDouble(),
      isSystem: json['is_system'] as bool? ?? false,
      username: json['username'] as String?,
      status: json['status'] as String?,
      memoryPercent: (json['memory_percent'] as num? ?? 0).toDouble(),
      threadCount: json['thread_count'] as int?,
      startedAt: _parseStartedAt(json['started_at']),
    );
  }

  static DateTime? _parseStartedAt(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
