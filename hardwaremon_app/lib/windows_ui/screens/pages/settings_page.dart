import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/chart_preferences.dart';
import '../../models/dashboard_preferences.dart';
import '../../services/settings_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/desktop_integration_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../widgets/update_center.dart';
import '../../../services/log_service.dart';
import '../../../services/diagnostics_service.dart';
import '../../../services/alert_service.dart';
import '../../../services/build_info_service.dart';
import '../../../services/update_service.dart';
import '../../../widgets/alert_settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;
  final DashboardPreferences dashboardPreferences;

  const SettingsPage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
    required this.dashboardPreferences,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService settingsService = SettingsService();
  final DesktopIntegrationService desktopIntegration =
      DesktopIntegrationService.instance;
  AppSettings settings = const AppSettings();
  RuntimeBuildInfo? buildInfo;

  @override
  void initState() {
    super.initState();
    desktopIntegration.addListener(_onDesktopIntegrationChanged);
    _loadSettings();
    _loadBuildInfo();
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

  Future<void> _loadBuildInfo() async {
    final loaded = await BuildInfoService().load();
    if (!mounted) return;
    setState(() => buildInfo = loaded);
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
    await widget.chartPreferences.resetDefaults();
    await widget.dashboardPreferences.resetDefaults();

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

          _buildSection('Experience', [
            _settingRow(
              'Ambient system pulse',
              Tooltip(
                message:
                    'Subtle background light that responds to CPU, memory, and temperature',
                child: Switch(
                  value: widget.chartPreferences.ambientEffects,
                  onChanged: (value) => widget.chartPreferences.setPreference(
                    ChartPreference.ambientEffects,
                    value,
                  ),
                ),
              ),
            ),
            _settingRow(
              'Live telemetry strip',
              Tooltip(
                message:
                    'Keep a compact health summary visible above every page',
                child: Switch(
                  value: widget.chartPreferences.telemetryTicker,
                  onChanged: (value) => widget.chartPreferences.setPreference(
                    ChartPreference.telemetryTicker,
                    value,
                  ),
                ),
              ),
            ),
            _settingRow(
              'Smooth chart updates',
              Switch(
                value: widget.chartPreferences.animations,
                onChanged: (value) => widget.chartPreferences.setPreference(
                  ChartPreference.animations,
                  value,
                ),
              ),
            ),
            _settingRow(
              'Command palette',
              _KeyboardShortcut(keys: const ['Ctrl', 'K']),
            ),
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
            const SizedBox(height: 8),
            const UpdateSettingsPanel(),
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

          AnimatedBuilder(
            animation: UpdateService.instance,
            builder: (context, _) =>
                _buildAboutSection(UpdateService.instance.state),
          ),
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

  Widget _buildAboutSection(UpdateState updateState) {
    final info = buildInfo;
    final cards = [
      _AboutDetail(
        label: 'Version',
        value: updateState.currentVersion,
        description: 'Installed application version',
        icon: Icons.tag_rounded,
        color: Colors.cyan,
      ),
      _AboutDetail(
        label: 'Release channel',
        value: updateState.channel.label,
        description: updateState.channel.buildDescription,
        icon: Icons.alt_route_rounded,
        color: updateState.channel == UpdateBuildChannel.stable
            ? Colors.greenAccent
            : Colors.purpleAccent,
      ),
      _AboutDetail(
        label: 'Build type',
        value: info?.buildType ?? 'Detecting…',
        description: 'Flutter compiler mode',
        icon: Icons.build_circle_outlined,
        color: Colors.orange,
      ),
      _AboutDetail(
        label: 'Platform',
        value: info?.platform ?? updateState.platform.label,
        description: updateState.packageType.label,
        icon: Icons.desktop_windows_rounded,
        color: Colors.blueAccent,
      ),
      _AboutDetail(
        label: 'Flutter',
        value: info?.flutterVersion ?? 'Detecting…',
        description: info?.flutterVersion == 'Not embedded'
            ? 'Build metadata was not embedded'
            : 'Framework version',
        icon: Icons.flutter_dash_rounded,
        color: Colors.lightBlueAccent,
      ),
      _AboutDetail(
        label: 'Backend',
        value: info?.backendVersion ?? 'Detecting…',
        description: 'Local FastAPI telemetry service',
        icon: Icons.dns_rounded,
        color: Colors.tealAccent,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.surface(context),
            Colors.purple.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.accent),
              SizedBox(width: 10),
              Text(
                'About HardwareMon',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Runtime and release information from the installed application.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: width,
                      child: _AboutCard(detail: card),
                    ),
                ],
              );
            },
          ),
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

class _AboutDetail {
  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _AboutDetail({
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _AboutCard extends StatefulWidget {
  final _AboutDetail detail;

  const _AboutCard({required this.detail});

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: detail.color.withValues(alpha: hovering ? 0.09 : 0.045),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: detail.color.withValues(alpha: hovering ? 0.3 : 0.12),
          ),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: detail.color.withValues(alpha: 0.08),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: detail.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(detail.icon, color: detail.color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.label,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyboardShortcut extends StatelessWidget {
  final List<String> keys;

  const _KeyboardShortcut({required this.keys});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < keys.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '+',
                style: TextStyle(color: AppColors.textMuted(context)),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.overlay(context, 0.05),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Text(
              keys[index],
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
