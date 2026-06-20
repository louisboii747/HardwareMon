import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/desktop_integration_service.dart';
import '../../../services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../../services/log_service.dart';
import '../../../services/diagnostics_service.dart';
import '../../../services/alert_service.dart';
import '../../../widgets/alert_settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  final TelemetryService telemetry;

  const SettingsPage({super.key, required this.telemetry});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService settingsService = SettingsService();
  final DesktopIntegrationService desktopIntegration =
      DesktopIntegrationService.instance;
  AppSettings settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    desktopIntegration.addListener(_onDesktopIntegrationChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    desktopIntegration.removeListener(_onDesktopIntegrationChanged);
    super.dispose();
  }

  void _onDesktopIntegrationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await settingsService.loadSettings();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings;
    });
    AlertService.instance.updateSettings(loadedSettings);
    desktopIntegration.applySettings(loadedSettings);
  }

  Future<void> _updateSettings(AppSettings updatedSettings) async {
    setState(() {
      settings = updatedSettings;
    });

    await settingsService.saveSettings(updatedSettings);
    AlertService.instance.updateSettings(updatedSettings);
    AppThemeController.instance.setTheme(updatedSettings.theme);
    desktopIntegration.applySettings(updatedSettings);
  }

  Future<void> _setLaunchOnStartup(bool enabled) async {
    final result = await desktopIntegration.setLaunchOnStartup(enabled);
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.description)));
      return;
    }

    await _updateSettings(settings.copyWith(launchOnStartup: result.enabled));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.description)));
  }

  Future<void> _setTraySetting({
    required bool value,
    required AppSettings Function(bool value) update,
  }) async {
    if (value && !desktopIntegration.trayAvailable) {
      final detail =
          desktopIntegration.trayError ??
          'The system tray is unavailable in this desktop environment.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));
      return;
    }

    await _updateSettings(update(value));
  }

  Future<void> _resetSettings() async {
    const defaults = AppSettings();
    final startupResult = await desktopIntegration.setLaunchOnStartup(
      defaults.launchOnStartup,
    );
    final effectiveDefaults = defaults.copyWith(
      launchOnStartup: startupResult.success && startupResult.enabled,
      minimiseToTray:
          defaults.minimiseToTray && desktopIntegration.trayAvailable,
      closeToTray: defaults.closeToTray && desktopIntegration.trayAvailable,
    );

    await settingsService.saveSettings(effectiveDefaults);

    setState(() {
      settings = effectiveDefaults;
    });

    AppThemeController.instance.setTheme(effectiveDefaults.theme);
    AlertService.instance.updateSettings(effectiveDefaults);
    desktopIntegration.applySettings(effectiveDefaults);
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
            ),
          ),

          const SizedBox(height: 24),

          _buildSection('General', [
            _settingRow(
              'Theme',
              DropdownButton<String>(
                value: settings.theme,
                items: const [
                  DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'Light', child: Text('Light')),
                ],
                onChanged: (value) async {
                  await _updateSettings(settings.copyWith(theme: value!));
                },
              ),
            ),

            _settingRow(
              'Launch on Startup',
              Switch(
                value: settings.launchOnStartup,
                onChanged: desktopIntegration.startupStatus.supported
                    ? _setLaunchOnStartup
                    : null,
              ),
            ),

            _settingRow(
              'Minimise to Tray',
              Switch(
                value: settings.minimiseToTray,
                onChanged: (value) => _setTraySetting(
                  value: value,
                  update: (enabled) =>
                      settings.copyWith(minimiseToTray: enabled),
                ),
              ),
            ),

            _settingRow(
              'Close to Tray',
              Switch(
                value: settings.closeToTray,
                onChanged: (value) => _setTraySetting(
                  value: value,
                  update: (enabled) => settings.copyWith(closeToTray: enabled),
                ),
              ),
            ),
            _desktopIntegrationStatus(),
          ]),

          _buildSection('Monitoring', [
            _settingRow(
              'Refresh Interval',
              DropdownButton<String>(
                value: settings.refreshInterval,
                items: const [
                  DropdownMenuItem(value: '1s', child: Text('1 second')),
                  DropdownMenuItem(value: '2s', child: Text('2 seconds')),
                  DropdownMenuItem(value: '5s', child: Text('5 seconds')),
                ],
                onChanged: (value) async {
                  await _updateSettings(
                    settings.copyWith(refreshInterval: value!),
                  );

                  await widget.telemetry.restart();
                },
              ),
            ),

            _settingRow(
              'Historical Monitoring',
              Switch(
                value: settings.historicalMonitoring,
                onChanged: (value) async {
                  await _updateSettings(
                    settings.copyWith(historicalMonitoring: value),
                  );
                },
              ),
            ),
          ]),

          _buildSection('Notifications', [
            _settingRow(
              'CPU Alerts',
              Switch(
                value: settings.cpuAlerts,
                onChanged: (value) async {
                  await _updateSettings(settings.copyWith(cpuAlerts: value));
                },
              ),
            ),

            _settingRow(
              'RAM Alerts',
              Switch(
                value: settings.ramAlerts,
                onChanged: (value) async {
                  await _updateSettings(settings.copyWith(ramAlerts: value));
                },
              ),
            ),

            _settingRow(
              'Temperature Alerts',
              Switch(
                value: settings.temperatureAlerts,
                onChanged: (value) async {
                  await _updateSettings(
                    settings.copyWith(temperatureAlerts: value),
                  );
                },
              ),
            ),

            _settingRow(
              'Disk Alerts',
              Switch(
                value: settings.diskAlerts,
                onChanged: (value) async {
                  await _updateSettings(settings.copyWith(diskAlerts: value));
                },
              ),
            ),

            _settingRow(
              'Alert Sounds',
              Switch(
                value: settings.alertSounds,
                onChanged: (value) async {
                  await _updateSettings(settings.copyWith(alertSounds: value));
                },
              ),
            ),
          ]),

          _buildSection('Alert Thresholds', [
            AlertThresholdSlider(
              label: 'CPU Usage',
              value: settings.cpuUsageThreshold,
              min: 0,
              max: 100,
              unit: '%',
              enabled: settings.cpuAlerts,
              enableMessage: 'Enable CPU Alerts to change this threshold.',
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(cpuUsageThreshold: value)),
            ),
            AlertThresholdSlider(
              label: 'RAM Usage',
              value: settings.ramUsageThreshold,
              min: 0,
              max: 100,
              unit: '%',
              enabled: settings.ramAlerts,
              enableMessage: 'Enable RAM Alerts to change this threshold.',
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(ramUsageThreshold: value)),
            ),
            AlertThresholdSlider(
              label: 'Disk Usage',
              value: settings.diskUsageThreshold,
              min: 0,
              max: 100,
              unit: '%',
              enabled: settings.diskAlerts,
              enableMessage: 'Enable Disk Alerts to change this threshold.',
              onChanged: (value) =>
                  _updateSettings(settings.copyWith(diskUsageThreshold: value)),
            ),
            AlertThresholdSlider(
              label: 'CPU Temperature',
              value: settings.cpuTemperatureThreshold,
              min: 0,
              max: 100,
              unit: '°C',
              enabled: settings.temperatureAlerts,
              enableMessage:
                  'Enable Temperature Alerts to change this threshold.',
              onChanged: (value) => _updateSettings(
                settings.copyWith(cpuTemperatureThreshold: value),
              ),
            ),
            AlertThresholdSlider(
              label: 'GPU Temperature',
              value: settings.gpuTemperatureThreshold,
              min: 0,
              max: 100,
              unit: '°C',
              enabled: settings.temperatureAlerts,
              enableMessage:
                  'Enable Temperature Alerts to change this threshold.',
              onChanged: (value) => _updateSettings(
                settings.copyWith(gpuTemperatureThreshold: value),
              ),
            ),
          ]),

          _buildSection('Alert History', [
            const AlertHistoryPanel(showHeader: false),
          ]),

          _buildSection('Updates', [
            _settingRow(
              'Auto Update Checks',
              Switch(
                value: settings.autoUpdateChecks,
                onChanged: (value) async {
                  await _updateSettings(
                    settings.copyWith(autoUpdateChecks: value),
                  );
                },
              ),
            ),

            _settingRow(
              'Check for Updates',
              ElevatedButton(
                onPressed: () async {
                  try {
                    final result = await UpdateService.checkForUpdates();

                    if (!context.mounted) return;

                    if (result['developmentBuild']) {
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Development Build'),
                          content: Text(
                            'You are running a development build.\n\n'
                            'Current: ${result['current']}\n'
                            'Latest Stable: ${result['latest']}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else if (result['updateAvailable']) {
                      final install = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Update Available'),
                          content: Text(
                            'Current Version: ${result['current']}\n'
                            'Latest Version: ${result['latest']}\n\n'
                            'Would you like to download the update now?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Later'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Download'),
                            ),
                          ],
                        ),
                      );

                      if (install == true) {
                        final path =
                            await UpdateService.downloadLatestRelease();

                        if (!context.mounted) return;

                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Download Complete'),
                            content: Text(
                              'Update downloaded successfully.\n\n'
                              'Saved to:\n$path',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Up To Date'),
                          content: const Text(
                            'You already have the latest version installed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to check for updates: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Check'),
              ),
            ),

            _settingRow(
              'Download Latest Release',
              ElevatedButton(
                onPressed: () async {
                  try {
                    final path = await UpdateService.downloadLatestRelease();

                    if (!context.mounted) return;

                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Download Complete'),
                        content: Text(
                          'Update downloaded successfully.\n\nSaved to:\n$path',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                },
                child: const Text('Download'),
              ),
            ),
          ]),

          _buildSection('Advanced', [
            _settingRow(
              'Open Logs Folder',
              ElevatedButton(
                onPressed: () async {
                  try {
                    await LogService.openLogsFolder();
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open logs folder: $e')),
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),

            _settingRow(
              'Export Diagnostics',
              ElevatedButton(
                onPressed: () async {
                  try {
                    final path = await DiagnosticsService.exportDiagnostics();

                    if (!context.mounted) return;

                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Diagnostics Exported'),
                        content: Text('Diagnostics saved to:\n\n$path'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to export diagnostics: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Export'),
              ),
            ),

            _settingRow(
              'Reset Settings',
              ElevatedButton(
                onPressed: _showResetDialog,
                child: const Text('Reset'),
              ),
            ),
          ]),

          _buildSection('About', [
            _settingRow('Version', const Text('18.0.0.dev')),

            _settingRow('Platform', const Text('Windows / Linux')),

            _settingRow('Backend', const Text('FastAPI')),

            _settingRow('Telemetry', const Text('LibreHardwareMonitor')),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }

  Widget _settingRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _desktopIntegrationStatus() {
    final startupStatus = desktopIntegration.startupStatus;
    final trayDetail = desktopIntegration.trayAvailable
        ? 'System tray integration is ready.'
        : desktopIntegration.trayError ??
              'System tray integration has not been initialized.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            startupStatus.description,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            trayDetail,
            style: TextStyle(
              color: desktopIntegration.trayAvailable
                  ? Colors.greenAccent
                  : Colors.amber,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
