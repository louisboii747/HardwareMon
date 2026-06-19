class AlertEvent {
  final String metricKey;
  final String metricLabel;
  final double value;
  final double threshold;
  final String unit;
  final DateTime occurredAt;

  const AlertEvent({
    required this.metricKey,
    required this.metricLabel,
    required this.value,
    required this.threshold,
    required this.unit,
    required this.occurredAt,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      metricKey: json['metricKey'] as String? ?? 'unknown',
      metricLabel: json['metricLabel'] as String? ?? 'Unknown metric',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metricKey': metricKey,
      'metricLabel': metricLabel,
      'value': value,
      'threshold': threshold,
      'unit': unit,
      'occurredAt': occurredAt.toIso8601String(),
    };
  }
}
