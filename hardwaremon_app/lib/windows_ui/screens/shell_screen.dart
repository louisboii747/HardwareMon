import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/chart_preferences.dart';
import '../models/dashboard_preferences.dart';
import '../models/telemetry_sample.dart';
import '../../services/update_prompt_service.dart';
import '../utils/telemetry_chart.dart';
import '../services/desktop_integration_service.dart';
import '../widgets/glass_panel.dart';
import '../widgets/metric_card.dart';
import '../widgets/metric_alert_action.dart';
import '../widgets/command_palette.dart';
import '../widgets/system_pulse_background.dart';
import '../widgets/telemetry_strip.dart';
import '../widgets/telemetry_studio.dart';
import 'pages/performance_page.dart';
import 'pages/processes_page.dart';
import 'pages/settings_page.dart';
import '../services/telemetry_service.dart';
import '../core/theme/app_colors.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late TelemetryService telemetry;
  late ChartPreferences chartPreferences;
  late DashboardPreferences dashboardPreferences;
  StreamSubscription<DesktopCommand>? _desktopCommandSubscription;

  int selectedIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();

    telemetry = TelemetryService();
    chartPreferences = ChartPreferences();
    dashboardPreferences = DashboardPreferences();

    telemetry.start();
    chartPreferences.load();
    dashboardPreferences.load();
    DesktopIntegrationService.instance.attachTelemetry(telemetry);
    _desktopCommandSubscription = DesktopIntegrationService.instance.commands
        .listen(_handleDesktopCommand);

    telemetry.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    chartPreferences.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    dashboardPreferences.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _desktopCommandSubscription?.cancel();
    DesktopIntegrationService.instance.detachTelemetry(telemetry);
    telemetry.stop();
    chartPreferences.dispose();
    dashboardPreferences.dispose();
    super.dispose();
  }

  Future<void> _handleDesktopCommand(DesktopCommand command) async {
    if (!mounted) return;

    switch (command) {
      case DesktopCommand.showHardwareMon:
        break;
      case DesktopCommand.telemetryStudio:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _selectPage(2);
        await _openTelemetryStudio();
        break;
      case DesktopCommand.checkForUpdates:
        await UpdatePromptService.checkForUpdates(context);
        break;
      case DesktopCommand.settings:
        Navigator.of(context).popUntil((route) => route.isFirst);
        _selectPage(3);
        break;
    }
  }

  void _selectPage(int index) {
    if (selectedIndex == index) return;
    setState(() {
      _previousIndex = selectedIndex;
      selectedIndex = index;
    });
  }

  Future<void> _openTelemetryStudio() {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            TelemetryStudioPage(
              telemetry: telemetry,
              chartPreferences: chartPreferences,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  SystemCondition get _systemCondition => evaluateSystemCondition(
    cpuUsage: telemetry.cpuUsage,
    ramUsage: telemetry.ramUsage,
    cpuTemperature: telemetry.cpuTemp,
    gpuTemperature: telemetry.gpuTemp,
    paused: telemetry.isPaused,
    hasError: telemetry.lastError != null,
  );

  Future<void> _copySystemSnapshot() async {
    final capturedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final snapshot =
        '''
HardwareMon snapshot · $capturedAt
Status: ${_systemCondition.label}
CPU: ${telemetry.cpuUsage}% · ${telemetry.cpuTemp}°C · ${telemetry.cpuClockGHz.toStringAsFixed(2)} GHz · ${telemetry.cpuPower.toStringAsFixed(1)} W
Memory: ${telemetry.ramUsage}% · ${telemetry.ramUsed.toStringAsFixed(1)} / ${telemetry.ramTotal.toStringAsFixed(1)} GB
GPU: ${telemetry.gpuUsage}% · ${telemetry.gpuTemp}°C · ${telemetry.gpuPower.toStringAsFixed(1)} W
Disk: ${telemetry.diskUsage}%
''';

    await Clipboard.setData(ClipboardData(text: snapshot.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live system snapshot copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showKeyboardShortcuts() {
    const shortcuts = [
      ('Command palette', 'Ctrl K'),
      ('Navigate pages', 'Alt 1–4'),
      ('Refresh telemetry', 'F5 / Ctrl R'),
      ('Pause or resume', 'Ctrl P'),
      ('Reset session statistics', 'Ctrl Shift R'),
      ('Copy live snapshot', 'Ctrl Shift C'),
      ('Open settings', 'Ctrl ,'),
    ];

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, size: 22),
            SizedBox(width: 10),
            Text('Keyboard shortcuts'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final shortcut in shortcuts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text(shortcut.$1)),
                      _ShortcutLabel(label: shortcut.$2),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  List<CommandPaletteAction> _commandPaletteActions() {
    return [
      CommandPaletteAction(
        id: 'dashboard',
        title: 'Open Dashboard',
        description: 'Return to the live system overview',
        section: 'Navigate',
        shortcut: 'Alt 1',
        icon: Icons.dashboard_rounded,
        selected: selectedIndex == 0,
        keywords: const ['home', 'overview'],
        run: () => _selectPage(0),
      ),
      CommandPaletteAction(
        id: 'processes',
        title: 'Open Processes',
        description: 'Inspect user and system resource usage',
        section: 'Navigate',
        shortcut: 'Alt 2',
        icon: Icons.list_rounded,
        selected: selectedIndex == 1,
        keywords: const ['apps', 'pid', 'tasks'],
        run: () => _selectPage(1),
      ),
      CommandPaletteAction(
        id: 'performance',
        title: 'Open Performance',
        description: 'Explore detailed live and historical metrics',
        section: 'Navigate',
        shortcut: 'Alt 3',
        icon: Icons.analytics_rounded,
        selected: selectedIndex == 2,
        keywords: const ['charts', 'graphs', 'history'],
        run: () => _selectPage(2),
      ),
      CommandPaletteAction(
        id: 'settings',
        title: 'Open Settings',
        description: 'Configure monitoring and desktop behaviour',
        section: 'Navigate',
        shortcut: 'Ctrl ,',
        icon: Icons.settings_rounded,
        selected: selectedIndex == 3,
        keywords: const ['preferences', 'configure'],
        run: () => _selectPage(3),
      ),
      for (final workspace in DashboardWorkspace.values)
        CommandPaletteAction(
          id: 'workspace-${workspace.name}',
          title: 'Apply ${workspace.label} Workspace',
          description: workspace.description,
          section: 'Dashboard workspaces',
          icon: switch (workspace) {
            DashboardWorkspace.overview => Icons.dashboard_customize_rounded,
            DashboardWorkspace.workload => Icons.speed_rounded,
            DashboardWorkspace.thermals => Icons.thermostat_rounded,
            DashboardWorkspace.power => Icons.bolt_rounded,
          },
          selected: dashboardPreferences.workspace == workspace,
          keywords: const ['dashboard', 'preset', 'layout', 'apply'],
          run: () {
            _selectPage(0);
            return _applyDashboardWorkspace(workspace);
          },
        ),
      CommandPaletteAction(
        id: 'studio',
        title: 'Launch Telemetry Studio',
        description: 'Compare CPU, memory, and GPU on one canvas',
        section: 'Telemetry',
        icon: Icons.stacked_line_chart_rounded,
        keywords: const ['compare', 'expanded', 'canvas'],
        run: _openTelemetryStudio,
      ),
      CommandPaletteAction(
        id: 'pause',
        title: telemetry.isPaused ? 'Resume Telemetry' : 'Pause Telemetry',
        description: telemetry.isPaused
            ? 'Continue collecting live samples'
            : 'Freeze the current telemetry view',
        section: 'Telemetry',
        shortcut: 'Ctrl P',
        icon: telemetry.isPaused
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded,
        selected: telemetry.isPaused,
        keywords: const ['freeze', 'live', 'resume'],
        run: telemetry.togglePaused,
      ),
      CommandPaletteAction(
        id: 'refresh',
        title: 'Refresh Everything Now',
        description: 'Fetch current values and historical telemetry',
        section: 'Telemetry',
        shortcut: 'F5',
        icon: Icons.refresh_rounded,
        keywords: const ['reload', 'sync', 'update'],
        run: () => telemetry.refreshNow(includeHistory: true),
      ),
      CommandPaletteAction(
        id: 'reset-statistics',
        title: 'Reset Session Min/Max',
        description: 'Start a fresh statistics window',
        section: 'Telemetry',
        shortcut: 'Ctrl Shift R',
        icon: Icons.restart_alt_rounded,
        keywords: const ['clear', 'session', 'minimum', 'maximum'],
        run: telemetry.resetSessionStatistics,
      ),
      CommandPaletteAction(
        id: 'copy-snapshot',
        title: 'Copy Live System Snapshot',
        description: 'Copy a timestamped diagnostic summary',
        section: 'Quick actions',
        shortcut: 'Ctrl Shift C',
        icon: Icons.content_copy_rounded,
        keywords: const ['clipboard', 'share', 'diagnostic'],
        run: _copySystemSnapshot,
      ),
      CommandPaletteAction(
        id: 'ambient',
        title: chartPreferences.ambientEffects
            ? 'Disable Ambient System Pulse'
            : 'Enable Ambient System Pulse',
        description: 'Let the background subtly reflect system activity',
        section: 'Appearance',
        icon: Icons.blur_on_rounded,
        selected: chartPreferences.ambientEffects,
        keywords: const ['background', 'glow', 'visual'],
        run: () => _toggleChartPreference(ChartPreference.ambientEffects),
      ),
      CommandPaletteAction(
        id: 'ticker',
        title: chartPreferences.telemetryTicker
            ? 'Hide Live Telemetry Strip'
            : 'Show Live Telemetry Strip',
        description: 'Toggle the compact system health summary',
        section: 'Appearance',
        icon: Icons.view_stream_rounded,
        selected: chartPreferences.telemetryTicker,
        keywords: const ['health', 'status', 'metrics'],
        run: () => _toggleChartPreference(ChartPreference.telemetryTicker),
      ),
      CommandPaletteAction(
        id: 'grid',
        title: chartPreferences.gridLines
            ? 'Hide Chart Grid Lines'
            : 'Show Chart Grid Lines',
        description: 'Change graph density across the application',
        section: 'Appearance',
        shortcut: 'Ctrl G',
        icon: Icons.grid_4x4_rounded,
        selected: chartPreferences.gridLines,
        keywords: const ['graph', 'chart'],
        run: () => _toggleChartPreference(ChartPreference.gridLines),
      ),
      CommandPaletteAction(
        id: 'shortcuts',
        title: 'Show Keyboard Shortcuts',
        description: 'See every global desktop shortcut',
        section: 'Help',
        icon: Icons.keyboard_rounded,
        keywords: const ['keys', 'hotkeys', 'help'],
        run: _showKeyboardShortcuts,
      ),
      CommandPaletteAction(
        id: 'updates',
        title: 'Check for Updates',
        description: 'Look for a newer HardwareMon release',
        section: 'Help',
        icon: Icons.system_update_alt_rounded,
        keywords: const ['version', 'release', 'upgrade'],
        run: () => UpdatePromptService.checkForUpdates(context),
      ),
    ];
  }

  Future<void> _showCommandPalette() {
    final telemetrySummary =
        'CPU ${telemetry.cpuUsage}%  ·  RAM ${telemetry.ramUsage}%  ·  GPU ${telemetry.gpuTemp}°';
    return showHardwareMonCommandPalette(
      context: context,
      actions: _commandPaletteActions(),
      systemSummary:
          '${_systemCondition.label} · ${_systemCondition.description}',
      telemetrySummary: telemetrySummary,
      systemColor: _systemCondition.color,
    );
  }

  Widget buildDashboard() {
    final metrics = _dashboardMetrics(dashboardPreferences.workspace);
    final cards = [
      for (var index = 0; index < metrics.length; index++)
        _buildDashboardMetricCard(metrics[index], index),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _DashboardWorkspaceSelector(
                  selected: dashboardPreferences.workspace,
                  onSelected: _applyDashboardWorkspace,
                ),
                const SizedBox(height: 14),
                SizedBox(height: 280, child: cards[0]),
                const SizedBox(height: 16),
                SizedBox(height: 230, child: cards[1]),
                const SizedBox(height: 16),
                SizedBox(height: 230, child: cards[2]),
              ],
            ),
          );
        }

        return Column(
          children: [
            _DashboardWorkspaceSelector(
              selected: dashboardPreferences.workspace,
              onSelected: _applyDashboardWorkspace,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 2, child: cards[0]),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: cards[1]),
                        const SizedBox(height: 16),
                        Expanded(child: cards[2]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyDashboardWorkspace(DashboardWorkspace workspace) async {
    await dashboardPreferences.setWorkspace(workspace);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${workspace.label} workspace applied'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Widget _buildDashboardMetricCard(_DashboardMetric metric, int index) {
    final card = MetricCard(
      title: metric.title,
      value: metric.value,
      subtitle: metric.subtitle,
      icon: metric.icon,
      accent: metric.accent,
      graphPoints: metric.samples,
      chartPreferences: chartPreferences,
      metricKind: metric.metricKind,
      statisticsSince: telemetry.sessionStatisticsStartedAt,
      alertKind: metric.alertKind,
      alertValue: metric.alertValue,
    );

    if (!chartPreferences.animations) return card;

    return card
        .animate(key: ValueKey('${dashboardPreferences.workspace.name}-$index'))
        .fadeIn(
          delay: Duration(milliseconds: index * 90),
          duration: 520.ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          delay: Duration(milliseconds: index * 90),
          duration: 520.ms,
          curve: Curves.easeOutCubic,
        );
  }

  List<_DashboardMetric> _dashboardMetrics(DashboardWorkspace workspace) {
    final cpuUsage = _DashboardMetric(
      title: 'CPU Usage',
      value: '${telemetry.cpuUsage}%',
      subtitle: telemetry.cpuName,
      icon: Icons.memory_rounded,
      accent: Colors.cyan,
      samples: telemetry.cpuHistory,
      alertKind: MetricAlertKind.cpuUsage,
      alertValue: telemetry.cpuUsage.toDouble(),
    );
    final memory = _DashboardMetric(
      title: 'Memory',
      value: '${telemetry.ramUsage}%',
      subtitle: 'System memory usage',
      icon: Icons.storage_rounded,
      accent: Colors.purple,
      samples: telemetry.ramHistory,
      alertKind: MetricAlertKind.ramUsage,
      alertValue: telemetry.ramUsage.toDouble(),
    );
    final gpuUsage = _DashboardMetric(
      title: 'GPU Usage',
      value: '${telemetry.gpuUsage}%',
      subtitle: 'Graphics workload',
      icon: Icons.show_chart_rounded,
      accent: Colors.lightBlueAccent,
      samples: telemetry.gpuUsageHistory,
    );
    final cpuTemperature = _DashboardMetric(
      title: 'CPU Temp',
      value: '${telemetry.cpuTemp}°',
      subtitle: 'Package temperature',
      icon: Icons.thermostat_rounded,
      accent: Colors.redAccent,
      samples: telemetry.cpuTempHistory,
      metricKind: TelemetryMetricKind.temperature,
      alertKind: MetricAlertKind.cpuTemperature,
      alertValue: telemetry.cpuTemp.toDouble(),
    );
    final gpuTemperature = _DashboardMetric(
      title: 'GPU Temp',
      value: '${telemetry.gpuTemp}°',
      subtitle: 'Graphics temperature',
      icon: Icons.graphic_eq_rounded,
      accent: Colors.orange,
      samples: telemetry.gpuTempHistory,
      metricKind: TelemetryMetricKind.temperature,
      alertKind: MetricAlertKind.gpuTemperature,
      alertValue: telemetry.gpuTemp.toDouble(),
    );
    final cpuPower = _DashboardMetric(
      title: 'CPU Power',
      value: '${telemetry.cpuPower.toStringAsFixed(1)} W',
      subtitle: 'Package power draw',
      icon: Icons.bolt_rounded,
      accent: Colors.amber,
      samples: telemetry.cpuPowerHistory,
      metricKind: TelemetryMetricKind.watts,
    );
    final gpuPower = _DashboardMetric(
      title: 'GPU Power',
      value: '${telemetry.gpuPower.toStringAsFixed(1)} W',
      subtitle: 'Board power draw',
      icon: Icons.electric_bolt_rounded,
      accent: Colors.lightGreenAccent,
      samples: telemetry.gpuPowerHistory,
      metricKind: TelemetryMetricKind.watts,
    );

    return switch (workspace) {
      DashboardWorkspace.overview => [cpuUsage, memory, gpuTemperature],
      DashboardWorkspace.workload => [cpuUsage, gpuUsage, memory],
      DashboardWorkspace.thermals => [cpuTemperature, gpuTemperature, cpuPower],
      DashboardWorkspace.power => [cpuPower, gpuPower, gpuUsage],
    };
  }

  Widget getCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return buildDashboard();

      case 1:
        return const ProcessesPage();

      case 2:
        return PerformancePage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
        );

      case 3:
        return SettingsPage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
          dashboardPreferences: dashboardPreferences,
        );

      default:
        return buildDashboard();
    }
  }

  Future<void> _toggleChartPreference(ChartPreference preference) {
    return chartPreferences.setPreference(
      preference,
      !chartPreferences.valueFor(preference),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final statusText = telemetry.lastError != null
        ? 'Connection issue'
        : telemetry.isPaused
        ? 'Paused'
        : telemetry.isRefreshing
        ? 'Refreshing'
        : telemetry.lastUpdated == null
        ? 'Connecting'
        : 'Live · ${DateFormat('HH:mm:ss').format(telemetry.lastUpdated!)}';

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CommandPaletteButton(onPressed: _showCommandPalette),
        const SizedBox(width: 8),
        _TelemetryStatus(
          label: statusText,
          paused: telemetry.isPaused,
          error: telemetry.lastError != null,
        ),
        const SizedBox(width: 8),
        _ShellControlButton(
          label: 'Refresh now',
          shortcut: 'Ctrl+R',
          icon: Icons.refresh_rounded,
          busy: telemetry.isRefreshing,
          onPressed: telemetry.isRefreshing
              ? null
              : () => telemetry.refreshNow(includeHistory: true),
        ),
        const SizedBox(width: 8),
        _ShellControlButton(
          label: telemetry.isPaused ? 'Resume telemetry' : 'Pause telemetry',
          shortcut: 'Ctrl+P',
          icon: telemetry.isPaused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          active: telemetry.isPaused,
          onPressed: telemetry.togglePaused,
        ),
        const SizedBox(width: 8),
        _ShellControlButton(
          label: 'Reset session min/max',
          shortcut: 'Ctrl+Shift+R',
          icon: Icons.restart_alt_rounded,
          onPressed: telemetry.resetSessionStatistics,
        ),
        const SizedBox(width: 8),
        _ChartOptionsButton(
          preferences: chartPreferences,
          onSelected: _toggleChartPreference,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HardwareMon',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: controls,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            const Text(
              'HardwareMon',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
            const Spacer(),
            controls,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
            _selectPage(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
            _selectPage(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
            _selectPage(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
            _selectPage(3),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): _showCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            telemetry.togglePaused(),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            telemetry.refreshNow(includeHistory: true),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            telemetry.refreshNow(includeHistory: true),
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          control: true,
          shift: true,
        ): telemetry.resetSessionStatistics,
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
            _toggleChartPreference(ChartPreference.gridLines),
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () =>
            _toggleChartPreference(ChartPreference.animations),
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): _copySystemSnapshot,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _selectPage(3),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,

                colors: AppColors.pageGradient(context),
              ),
            ),

            child: Stack(
              children: [
                SystemPulseBackground(
                  cpuUsage: telemetry.cpuUsage,
                  ramUsage: telemetry.ramUsage,
                  gpuTemperature: telemetry.gpuTemp,
                  enabled: chartPreferences.ambientEffects,
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),

                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,

                          child: GlassPanel(
                            padding: const EdgeInsets.symmetric(vertical: 20),

                            child: Column(
                              children: [
                                const Icon(
                                  Icons.memory_rounded,
                                  color: AppColors.accent,
                                  size: 28,
                                ),

                                const SizedBox(height: 32),

                                _DockItem(
                                  icon: Icons.dashboard_rounded,
                                  label: 'Dashboard',
                                  shortcut: 'Alt+1',
                                  active: selectedIndex == 0,
                                  onTap: () => _selectPage(0),
                                ),

                                const SizedBox(height: 12),

                                _DockItem(
                                  icon: Icons.list_rounded,
                                  label: 'Processes',
                                  shortcut: 'Alt+2',
                                  active: selectedIndex == 1,
                                  onTap: () => _selectPage(1),
                                ),

                                const SizedBox(height: 12),

                                _DockItem(
                                  icon: Icons.analytics_rounded,
                                  label: 'Performance',
                                  shortcut: 'Alt+3',
                                  active: selectedIndex == 2,
                                  onTap: () => _selectPage(2),
                                ),

                                const SizedBox(height: 12),

                                _DockItem(
                                  icon: Icons.settings_rounded,
                                  label: 'Settings',
                                  shortcut: 'Alt+4',
                                  active: selectedIndex == 3,
                                  onTap: () => _selectPage(3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 24),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const SizedBox(height: 8),

                              _buildHeader(context),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SizeTransition(
                                        sizeFactor: animation,
                                        alignment: Alignment.topCenter,
                                        child: child,
                                      ),
                                    ),
                                child: chartPreferences.telemetryTicker
                                    ? Padding(
                                        key: const ValueKey(
                                          'telemetry-strip-visible',
                                        ),
                                        padding: const EdgeInsets.only(top: 16),
                                        child: TelemetryStrip(
                                          cpuUsage: telemetry.cpuUsage,
                                          cpuTemperature: telemetry.cpuTemp,
                                          ramUsage: telemetry.ramUsage,
                                          gpuUsage: telemetry.gpuUsage,
                                          gpuTemperature: telemetry.gpuTemp,
                                          diskUsage: telemetry.diskUsage,
                                          paused: telemetry.isPaused,
                                          hasError: telemetry.lastError != null,
                                          onOpenPerformance: () =>
                                              _selectPage(2),
                                          onCopySnapshot: _copySystemSnapshot,
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('telemetry-strip-hidden'),
                                      ),
                              ),

                              SizedBox(
                                height: chartPreferences.telemetryTicker
                                    ? 20
                                    : 32,
                              ),

                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: chartPreferences.animations
                                      ? const Duration(milliseconds: 420)
                                      : Duration.zero,

                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeOutCubic,

                                  transitionBuilder: (child, animation) {
                                    final direction =
                                        selectedIndex >= _previousIndex
                                        ? 1.0
                                        : -1.0;
                                    return FadeTransition(
                                      opacity: animation,

                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(0.025 * direction, 0),
                                          end: Offset.zero,
                                        ).animate(animation),

                                        child: child,
                                      ),
                                    );
                                  },

                                  child: KeyedSubtree(
                                    key: ValueKey(selectedIndex),
                                    child: getCurrentPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<TelemetrySample> samples;
  final TelemetryMetricKind metricKind;
  final MetricAlertKind? alertKind;
  final double? alertValue;

  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.samples,
    this.metricKind = TelemetryMetricKind.percentage,
    this.alertKind,
    this.alertValue,
  });
}

class _DashboardWorkspaceSelector extends StatelessWidget {
  final DashboardWorkspace selected;
  final ValueChanged<DashboardWorkspace> onSelected;

  const _DashboardWorkspaceSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dashboard_customize_rounded,
            size: 17,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'Workspace',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final workspace in DashboardWorkspace.values) ...[
                    ChoiceChip(
                      label: Text(workspace.label),
                      selected: workspace == selected,
                      onSelected: (_) => onSelected(workspace),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: AppColors.accent.withValues(alpha: 0.18),
                      side: BorderSide(
                        color: workspace == selected
                            ? AppColors.accent.withValues(alpha: 0.36)
                            : AppColors.border(context),
                      ),
                      labelStyle: TextStyle(
                        color: workspace == selected
                            ? AppColors.textPrimary(context)
                            : AppColors.textMuted(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (workspace != DashboardWorkspace.values.last)
                      const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: selected.description,
            child: Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final bool active;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool hovering = false;
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.textPrimary(context);
    final inactiveColor = AppColors.textSecondary(context);

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      child: Tooltip(
        message: '${widget.label}  •  ${widget.shortcut}',
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => hovering = true),
            onExit: (_) => setState(() => hovering = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: widget.active || hovering || focused
                      ? AppColors.overlay(context, 0.08)
                      : Colors.transparent,
                  border: Border.all(
                    color: focused
                        ? AppColors.accent.withValues(alpha: 0.7)
                        : Colors.transparent,
                  ),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: Colors.cyan.withValues(alpha: 0.18),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.active ? activeColor : inactiveColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandPaletteButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CommandPaletteButton({required this.onPressed});

  @override
  State<_CommandPaletteButton> createState() => _CommandPaletteButtonState();
}

class _CommandPaletteButtonState extends State<_CommandPaletteButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open command palette  •  Ctrl+K',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: _hovering
                  ? AppColors.accent.withValues(alpha: 0.13)
                  : AppColors.overlay(context, 0.045),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovering
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.border(context),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: _hovering
                      ? AppColors.accent
                      : AppColors.textSecondary(context),
                ),
                const SizedBox(width: 7),
                Text(
                  'Quick actions',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 9),
                const _ShortcutLabel(label: 'Ctrl K'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutLabel extends StatelessWidget {
  final String label;

  const _ShortcutLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.055),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textMuted(context),
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TelemetryStatus extends StatelessWidget {
  final String label;
  final bool paused;
  final bool error;

  const _TelemetryStatus({
    required this.label,
    required this.paused,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final color = error
        ? Colors.redAccent
        : paused
        ? Colors.amber
        : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellControlButton extends StatelessWidget {
  final String label;
  final String shortcut;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final bool busy;

  const _ShellControlButton({
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label  •  $shortcut',
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: active
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.overlay(context, 0.045),
            foregroundColor: active
                ? AppColors.accent
                : AppColors.textSecondary(context),
            disabledForegroundColor: AppColors.textMuted(context),
            minimumSize: const Size(38, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.border(context),
              ),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _ChartOptionsButton extends StatelessWidget {
  final ChartPreferences preferences;
  final ValueChanged<ChartPreference> onSelected;

  const _ChartOptionsButton({
    required this.preferences,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Display options',
      child: PopupMenuButton<ChartPreference>(
        tooltip: '',
        onSelected: onSelected,
        color: AppColors.surfaceElevated(context),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          PopupMenuItem<ChartPreference>(
            enabled: false,
            height: 28,
            child: Text(
              'INTERFACE',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.ambientEffects,
            checked: preferences.ambientEffects,
            child: const Text('Ambient system pulse'),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.telemetryTicker,
            checked: preferences.telemetryTicker,
            child: const Text('Live telemetry strip'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<ChartPreference>(
            enabled: false,
            height: 28,
            child: Text(
              'CHARTS',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.smoothLines,
            checked: preferences.smoothLines,
            child: const Text('Smooth curves'),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.areaFill,
            checked: preferences.areaFill,
            child: const Text('Gradient area fill'),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.gridLines,
            checked: preferences.gridLines,
            child: const Text('Chart grid lines'),
          ),
          CheckedPopupMenuItem(
            value: ChartPreference.animations,
            checked: preferences.animations,
            child: const Text('Smooth updates'),
          ),
        ],
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.overlay(context, 0.045),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 18,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
