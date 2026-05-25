class ProcessInfo {
  final int pid;
  final String name;
  final double cpu;
  final double ram;

  ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.ram,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'],
      name: json['name'] ?? 'Unknown',
      cpu: (json['cpu'] as num).toDouble(),
      ram: (json['ram'] as num).toDouble(),
    );
  }
}
