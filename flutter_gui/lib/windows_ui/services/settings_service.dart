import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String> getString(String key, String defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('theme', settings.theme);
    await prefs.setString('refreshInterval', settings.refreshInterval);

    await prefs.setBool('launchOnStartup', settings.launchOnStartup);
    await prefs.setBool('minimiseToTray', settings.minimiseToTray);
    await prefs.setBool('closeToTray', settings.closeToTray);
    await prefs.setBool('historicalMonitoring', settings.historicalMonitoring);

    await prefs.setBool('cpuAlerts', settings.cpuAlerts);
    await prefs.setBool('ramAlerts', settings.ramAlerts);
    await prefs.setBool('temperatureAlerts', settings.temperatureAlerts);
    await prefs.setBool('diskAlerts', settings.diskAlerts);
    await prefs.setBool('alertSounds', settings.alertSounds);

    await prefs.setDouble(
      'cpuTemperatureThreshold',
      settings.cpuTemperatureThreshold,
    );
    await prefs.setDouble(
      'gpuTemperatureThreshold',
      settings.gpuTemperatureThreshold,
    );
    await prefs.setDouble('cpuUsageThreshold', settings.cpuUsageThreshold);
    await prefs.setDouble('ramUsageThreshold', settings.ramUsageThreshold);
    await prefs.setDouble('diskUsageThreshold', settings.diskUsageThreshold);

    await prefs.setBool('autoUpdateChecks', settings.autoUpdateChecks);
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      theme: prefs.getString('theme') ?? 'Dark',
      refreshInterval: prefs.getString('refreshInterval') ?? '1s',

      launchOnStartup: prefs.getBool('launchOnStartup') ?? true,

      minimiseToTray: prefs.getBool('minimiseToTray') ?? true,

      closeToTray: prefs.getBool('closeToTray') ?? true,

      historicalMonitoring: prefs.getBool('historicalMonitoring') ?? true,

      cpuAlerts: prefs.getBool('cpuAlerts') ?? false,

      ramAlerts: prefs.getBool('ramAlerts') ?? false,

      temperatureAlerts: prefs.getBool('temperatureAlerts') ?? false,

      diskAlerts: prefs.getBool('diskAlerts') ?? false,

      alertSounds: prefs.getBool('alertSounds') ?? true,

      cpuTemperatureThreshold: prefs.getDouble('cpuTemperatureThreshold') ?? 85,

      gpuTemperatureThreshold: prefs.getDouble('gpuTemperatureThreshold') ?? 85,

      cpuUsageThreshold: prefs.getDouble('cpuUsageThreshold') ?? 90,

      ramUsageThreshold: prefs.getDouble('ramUsageThreshold') ?? 90,

      diskUsageThreshold: prefs.getDouble('diskUsageThreshold') ?? 90,

      autoUpdateChecks: prefs.getBool('autoUpdateChecks') ?? true,
    );
  }
}
