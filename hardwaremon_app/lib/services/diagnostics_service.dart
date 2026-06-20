import 'dart:io';

import 'log_service.dart';
import '../windows_ui/models/app_settings.dart';
import '../windows_ui/services/settings_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../windows_ui/core/backend_config.dart';
import '../windows_ui/services/network_service.dart';

class DiagnosticsService {
  static Future<String> exportDiagnostics() async {
    final logsDir = await LogService.getLogsDirectory();

    final file = File(
      Platform.isWindows
          ? '$logsDir\\diagnostics.txt'
          : '$logsDir/diagnostics.txt',
    );
    final settingsService = SettingsService();
    final AppSettings settings = await settingsService.loadSettings();
    final packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic>? telemetry;
    Map<String, dynamic>? networkTelemetry;
    Map<String, dynamic>? lastPingResult;
    String? selectedInterface;

    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/stats'),
      );

      telemetry = jsonDecode(response.body);
    } catch (_) {
      telemetry = null;
    }

    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/network'),
      );
      if (response.statusCode == 200) {
        networkTelemetry = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
      }
    } catch (_) {
      networkTelemetry = null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      selectedInterface = prefs.getString(NetworkService.selectedInterfaceKey);
      final encodedResult = prefs.getString(NetworkService.lastPingResultKey);
      if (encodedResult != null) {
        lastPingResult = Map<String, dynamic>.from(
          jsonDecode(encodedResult) as Map,
        );
      }
    } catch (_) {
      lastPingResult = null;
    }

    final buffer = StringBuffer();

    buffer.writeln('HardwareMon Diagnostics');
    buffer.writeln('=======================');
    buffer.writeln('');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');

    buffer.writeln('Platform Information');
    buffer.writeln('--------------------');
    buffer.writeln('OS: ${Platform.operatingSystem}');
    buffer.writeln('OS Version: ${Platform.operatingSystemVersion}');
    buffer.writeln('');
    buffer.writeln('Settings');
    buffer.writeln('--------');
    buffer.writeln('Theme: ${settings.theme}');
    buffer.writeln('Launch On Startup: ${settings.launchOnStartup}');
    buffer.writeln('Minimise To Tray: ${settings.minimiseToTray}');
    buffer.writeln('Close To Tray: ${settings.closeToTray}');
    buffer.writeln('Refresh Interval: ${settings.refreshInterval}');
    buffer.writeln('Historical Monitoring: ${settings.historicalMonitoring}');
    buffer.writeln('CPU Alerts: ${settings.cpuAlerts}');
    buffer.writeln('RAM Alerts: ${settings.ramAlerts}');
    buffer.writeln('Temperature Alerts: ${settings.temperatureAlerts}');
    buffer.writeln('Disk Alerts: ${settings.diskAlerts}');
    buffer.writeln('Alert Sounds: ${settings.alertSounds}');
    buffer.writeln(
      'CPU Usage Threshold: ${settings.cpuUsageThreshold.toStringAsFixed(0)}%',
    );
    buffer.writeln(
      'RAM Usage Threshold: ${settings.ramUsageThreshold.toStringAsFixed(0)}%',
    );
    buffer.writeln(
      'Disk Usage Threshold: ${settings.diskUsageThreshold.toStringAsFixed(0)}%',
    );
    buffer.writeln(
      'CPU Temperature Threshold: '
      '${settings.cpuTemperatureThreshold.toStringAsFixed(0)}°C',
    );
    buffer.writeln(
      'GPU Temperature Threshold: '
      '${settings.gpuTemperatureThreshold.toStringAsFixed(0)}°C',
    );
    buffer.writeln('Auto Update Checks: ${settings.autoUpdateChecks}');
    buffer.writeln('');
    buffer.writeln('Paths');
    buffer.writeln('-----');
    buffer.writeln('Logs Directory:');
    buffer.writeln(logsDir);
    buffer.writeln('');
    buffer.writeln('Diagnostics File:');
    buffer.writeln(file.path);
    buffer.writeln('');
    buffer.writeln('Application');
    buffer.writeln('-----------');
    buffer.writeln('Version: ${packageInfo.version}');
    buffer.writeln('Build Number: ${packageInfo.buildNumber}');
    buffer.writeln('Backend: FastAPI');
    buffer.writeln('Telemetry Source: LibreHardwareMonitor');
    buffer.writeln('');
    buffer.writeln('Backend');
    buffer.writeln('-------');
    buffer.writeln('URL: ${BackendConfig.baseUrl}');
    buffer.writeln(
      'Status: ${telemetry != null ? "Reachable" : "Unavailable"}',
    );
    buffer.writeln('');
    buffer.writeln('Live Telemetry');
    buffer.writeln('--------------');

    if (telemetry != null) {
      buffer.writeln('CPU Name: ${telemetry['cpu_name']}');
      buffer.writeln('CPU Usage: ${telemetry['cpu']}%');
      buffer.writeln('CPU Temperature: ${telemetry['cpu_temp']}°C');
      buffer.writeln('CPU Clock: ${telemetry['cpu_clock']} MHz');
      buffer.writeln('CPU Power: ${telemetry['cpu_power']} W');
      buffer.writeln('');

      buffer.writeln('RAM Usage: ${telemetry['ram']}%');
      buffer.writeln('RAM Used: ${telemetry['ram_used']} GB');
      buffer.writeln('RAM Available: ${telemetry['ram_available']} GB');
      buffer.writeln('RAM Total: ${telemetry['ram_total']} GB');
      buffer.writeln('');

      buffer.writeln('GPU Usage: ${telemetry['gpu_usage']}%');
      buffer.writeln('GPU Temperature: ${telemetry['gpu_temp']}°C');
      buffer.writeln('GPU Power: ${telemetry['gpu_power']} W');
      buffer.writeln('GPU VRAM Used: ${telemetry['gpu_vram_used']} GB');
    } else {
      buffer.writeln('Telemetry unavailable');
    }

    buffer.writeln('');
    buffer.writeln('Network');
    buffer.writeln('-------');
    buffer.writeln(
      'Endpoint Status: ${networkTelemetry != null ? "Reachable" : "Unavailable"}',
    );
    if (networkTelemetry != null) {
      final interfaces =
          networkTelemetry['interfaces'] as List<dynamic>? ?? const [];
      buffer.writeln(
        'Selected Interface: ${selectedInterface ?? networkTelemetry['active_interface'] ?? 'None'}',
      );
      buffer.writeln(
        'Active Interface: ${networkTelemetry['active_interface'] ?? 'None'}',
      );
      buffer.writeln(
        'Local IP: ${networkTelemetry['local_ip'] ?? 'Unavailable'}',
      );
      buffer.writeln(
        'Gateway: ${networkTelemetry['gateway'] ?? 'Unavailable'}',
      );
      buffer.writeln('Download Speed: ${networkTelemetry['download_bps']} B/s');
      buffer.writeln('Upload Speed: ${networkTelemetry['upload_bps']} B/s');
      buffer.writeln('Total Received: ${networkTelemetry['bytes_received']} B');
      buffer.writeln('Total Sent: ${networkTelemetry['bytes_sent']} B');
      buffer.writeln(
        'Available Interfaces: ${interfaces.map((item) => item is Map ? item['name'] : item).join(', ')}',
      );
    } else {
      buffer.writeln('Network telemetry unavailable');
    }
    buffer.writeln('');

    buffer.writeln('Last Ping Result');
    buffer.writeln('----------------');
    if (lastPingResult != null) {
      buffer.writeln('Target: ${lastPingResult['target']}');
      buffer.writeln('Resolved Host: ${lastPingResult['resolved_host']}');
      buffer.writeln('Reachable: ${lastPingResult['reachable']}');
      buffer.writeln('Latency: ${lastPingResult['latency_ms']} ms');
      buffer.writeln('Average: ${lastPingResult['average_ms']} ms');
      buffer.writeln('Minimum: ${lastPingResult['min_ms']} ms');
      buffer.writeln('Maximum: ${lastPingResult['max_ms']} ms');
      buffer.writeln('Jitter: ${lastPingResult['jitter_ms']} ms');
      buffer.writeln('Packet Loss: ${lastPingResult['packet_loss_percent']}%');
      buffer.writeln('Samples: ${lastPingResult['samples']}');
      buffer.writeln('Checked At: ${lastPingResult['checked_at']}');
      buffer.writeln('Error: ${lastPingResult['error'] ?? 'None'}');
    } else {
      buffer.writeln('No ping result has been recorded.');
    }
    buffer.writeln('');

    final updaterLog = File(
      Platform.isWindows ? '$logsDir\\updater.log' : '$logsDir/updater.log',
    );
    buffer.writeln('Updater');
    buffer.writeln('-------');
    buffer.writeln('Log: ${updaterLog.path}');
    if (await updaterLog.exists()) {
      final content = await updaterLog.readAsString();
      const maxCharacters = 40000;
      buffer.writeln(
        content.length > maxCharacters
            ? content.substring(content.length - maxCharacters)
            : content,
      );
    } else {
      buffer.writeln('No updater log has been created yet.');
    }
    buffer.writeln('');

    await file.writeAsString(buffer.toString());

    return file.path;
  }
}
