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
  final bool alertSounds;

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
    this.alertSounds = true,
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
    bool? alertSounds,
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
      alertSounds: alertSounds ?? this.alertSounds,
      autoUpdateChecks: autoUpdateChecks ?? this.autoUpdateChecks,
    );
  }
}
