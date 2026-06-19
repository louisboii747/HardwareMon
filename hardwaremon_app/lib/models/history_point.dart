class HistoryPoint {
  final double cpuPercent;
  final double ramPercent;
  final double cpuTemp;
  final DateTime timestamp;

  HistoryPoint({
    required this.cpuPercent,
    required this.ramPercent,
    required this.cpuTemp,
    required this.timestamp,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      cpuPercent: (json['cpu_percent'] ?? 0).toDouble(),
      ramPercent: (json['ram_percent'] ?? 0).toDouble(),
      cpuTemp: (json['cpu_temp'] ?? 0).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
