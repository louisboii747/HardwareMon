class ProcessInfo {
  final int pid;
  final String name;
  final double cpu;
  final double ram;
  final bool isSystem;

  ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.ram,
    required this.isSystem,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'],
      name: json['name'] ?? 'Unknown',
      cpu: (json['cpu'] as num).toDouble(),
      ram: (json['ram'] as num).toDouble(),
      isSystem: json['is_system'] as bool? ?? false,
    );
  }
}
