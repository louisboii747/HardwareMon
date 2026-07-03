class TelemetryCapabilities {
  final bool supportsCpuUsage;
  final bool supportsMemory;
  final bool supportsDisk;
  final bool supportsNetwork;
  final bool supportsBattery;
  final bool supportsProcessList;
  final bool supportsProcessKill;
  final bool supportsCpuTemperature;
  final bool supportsGpuTemperature;
  final bool supportsFanControl;
  final bool supportsFanMetrics;
  final bool supportsPowerMetrics;
  final bool supportsCpuFrequency;
  final bool supportsGpuUsage;
  final bool supportsGpuVram;
  final bool supportsHistoricalMonitoring;
  final bool supportsNotifications;

  const TelemetryCapabilities({
    required this.supportsCpuUsage,
    required this.supportsMemory,
    required this.supportsDisk,
    required this.supportsNetwork,
    required this.supportsBattery,
    required this.supportsProcessList,
    required this.supportsProcessKill,
    required this.supportsCpuTemperature,
    required this.supportsGpuTemperature,
    required this.supportsFanControl,
    required this.supportsFanMetrics,
    required this.supportsPowerMetrics,
    required this.supportsCpuFrequency,
    required this.supportsGpuUsage,
    required this.supportsGpuVram,
    required this.supportsHistoricalMonitoring,
    required this.supportsNotifications,
  });

  factory TelemetryCapabilities.fallback({required bool isMacOS}) {
    return TelemetryCapabilities(
      supportsCpuUsage: true,
      supportsMemory: true,
      supportsDisk: true,
      supportsNetwork: true,
      supportsBattery: false,
      supportsProcessList: true,
      supportsProcessKill: !isMacOS,
      supportsCpuTemperature: !isMacOS,
      supportsGpuTemperature: !isMacOS,
      supportsFanControl: false,
      supportsFanMetrics: false,
      supportsPowerMetrics: !isMacOS,
      supportsCpuFrequency: !isMacOS,
      supportsGpuUsage: !isMacOS,
      supportsGpuVram: !isMacOS,
      supportsHistoricalMonitoring: true,
      supportsNotifications: true,
    );
  }

  factory TelemetryCapabilities.fromJson(
    Map<String, dynamic>? json, {
    required bool isMacOS,
  }) {
    final fallback = TelemetryCapabilities.fallback(isMacOS: isMacOS);
    bool read(String key, bool value) =>
        json?[key] is bool ? json![key] as bool : value;

    return TelemetryCapabilities(
      supportsCpuUsage: read('supports_cpu_usage', fallback.supportsCpuUsage),
      supportsMemory: read('supports_memory', fallback.supportsMemory),
      supportsDisk: read('supports_disk', fallback.supportsDisk),
      supportsNetwork: read('supports_network', fallback.supportsNetwork),
      supportsBattery: read('supports_battery', fallback.supportsBattery),
      supportsProcessList: read(
        'supports_process_list',
        fallback.supportsProcessList,
      ),
      supportsProcessKill: read(
        'supports_process_kill',
        fallback.supportsProcessKill,
      ),
      supportsCpuTemperature: read(
        'supports_cpu_temperature',
        fallback.supportsCpuTemperature,
      ),
      supportsGpuTemperature: read(
        'supports_gpu_temperature',
        fallback.supportsGpuTemperature,
      ),
      supportsFanControl: read(
        'supports_fan_control',
        fallback.supportsFanControl,
      ),
      supportsFanMetrics: read(
        'supports_fan_metrics',
        fallback.supportsFanMetrics,
      ),
      supportsPowerMetrics: read(
        'supports_power_metrics',
        fallback.supportsPowerMetrics,
      ),
      supportsCpuFrequency: read(
        'supports_cpu_frequency',
        fallback.supportsCpuFrequency,
      ),
      supportsGpuUsage: read('supports_gpu_usage', fallback.supportsGpuUsage),
      supportsGpuVram: read('supports_gpu_vram', fallback.supportsGpuVram),
      supportsHistoricalMonitoring: read(
        'supports_historical_monitoring',
        fallback.supportsHistoricalMonitoring,
      ),
      supportsNotifications: read(
        'supports_notifications',
        fallback.supportsNotifications,
      ),
    );
  }

  Map<String, bool> toDiagnosticMap() => {
    'CPU usage': supportsCpuUsage,
    'Memory': supportsMemory,
    'Disk': supportsDisk,
    'Network': supportsNetwork,
    'Battery': supportsBattery,
    'Process list': supportsProcessList,
    'Process termination': supportsProcessKill,
    'CPU temperature': supportsCpuTemperature,
    'GPU temperature': supportsGpuTemperature,
    'Fan control': supportsFanControl,
    'Fan metrics': supportsFanMetrics,
    'Power metrics': supportsPowerMetrics,
    'CPU frequency': supportsCpuFrequency,
    'GPU usage': supportsGpuUsage,
    'Dedicated VRAM': supportsGpuVram,
    'Historical monitoring': supportsHistoricalMonitoring,
    'Notifications': supportsNotifications,
  };
}

class TelemetryPlatformInfo {
  final String system;
  final String name;
  final String version;
  final String architecture;
  final String deviceName;
  final String? modelIdentifier;
  final String? modelName;
  final String? chipName;

  const TelemetryPlatformInfo({
    required this.system,
    required this.name,
    required this.version,
    required this.architecture,
    required this.deviceName,
    this.modelIdentifier,
    this.modelName,
    this.chipName,
  });

  factory TelemetryPlatformInfo.fromJson(Map<String, dynamic>? json) {
    String read(String key, String fallback) {
      final value = json?[key]?.toString().trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    return TelemetryPlatformInfo(
      system: read('system', 'Unknown'),
      name: read('name', 'Unknown'),
      version: read('version', 'Unknown'),
      architecture: read('architecture', 'Unknown'),
      deviceName: read('device_name', 'Unknown device'),
      modelIdentifier: json?['model_identifier']?.toString(),
      modelName: json?['model_name']?.toString(),
      chipName: json?['chip_name']?.toString(),
    );
  }
}
