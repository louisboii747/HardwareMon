class AppSettings {
  final String theme;
  final String refreshInterval;

  final bool launchOnStartup;
  final bool minimiseToTray;
  final bool closeToTray;
  final bool historicalMonitoring;

  final bool cpuAlerts;
  final bool ramAlerts;
  final bool temperatureAlerts;
  final bool diskAlerts;
  final bool alertSounds;

  final double cpuTemperatureThreshold;
  final double gpuTemperatureThreshold;
  final double cpuUsageThreshold;
  final double ramUsageThreshold;
  final double diskUsageThreshold;

  final bool autoUpdateChecks;

  const AppSettings({
    this.theme = 'Dark',
    this.refreshInterval = '1s',
    this.launchOnStartup = true,
    this.minimiseToTray = true,
    this.closeToTray = true,
    this.historicalMonitoring = true,
    this.cpuAlerts = false,
    this.ramAlerts = false,
    this.temperatureAlerts = false,
    this.diskAlerts = false,
    this.alertSounds = true,
    this.cpuTemperatureThreshold = 85,
    this.gpuTemperatureThreshold = 85,
    this.cpuUsageThreshold = 90,
    this.ramUsageThreshold = 90,
    this.diskUsageThreshold = 90,
    this.autoUpdateChecks = true,
  });

  AppSettings copyWith({
    String? theme,
    String? refreshInterval,
    bool? launchOnStartup,
    bool? minimiseToTray,
    bool? closeToTray,
    bool? historicalMonitoring,
    bool? cpuAlerts,
    bool? ramAlerts,
    bool? temperatureAlerts,
    bool? diskAlerts,
    bool? alertSounds,
    double? cpuTemperatureThreshold,
    double? gpuTemperatureThreshold,
    double? cpuUsageThreshold,
    double? ramUsageThreshold,
    double? diskUsageThreshold,
    bool? autoUpdateChecks,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      launchOnStartup: launchOnStartup ?? this.launchOnStartup,
      minimiseToTray: minimiseToTray ?? this.minimiseToTray,
      closeToTray: closeToTray ?? this.closeToTray,
      historicalMonitoring: historicalMonitoring ?? this.historicalMonitoring,
      cpuAlerts: cpuAlerts ?? this.cpuAlerts,
      ramAlerts: ramAlerts ?? this.ramAlerts,
      temperatureAlerts: temperatureAlerts ?? this.temperatureAlerts,
      diskAlerts: diskAlerts ?? this.diskAlerts,
      alertSounds: alertSounds ?? this.alertSounds,
      cpuTemperatureThreshold:
          cpuTemperatureThreshold ?? this.cpuTemperatureThreshold,
      gpuTemperatureThreshold:
          gpuTemperatureThreshold ?? this.gpuTemperatureThreshold,
      cpuUsageThreshold: cpuUsageThreshold ?? this.cpuUsageThreshold,
      ramUsageThreshold: ramUsageThreshold ?? this.ramUsageThreshold,
      diskUsageThreshold: diskUsageThreshold ?? this.diskUsageThreshold,
      autoUpdateChecks: autoUpdateChecks ?? this.autoUpdateChecks,
    );
  }
}
