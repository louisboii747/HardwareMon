/*
THESIS
HardwareMon is a field service binder for a live machine: orderly, legible,
repairable, and quietly precise rather than theatrical.

OWN-WORLD
Graphite hardware, warm laminated work sheets, ruled registers, work-order blue,
and a small warning bracket make the product feel built for actual operators.

STORY
The rail identifies the instrument. The header names the current register. The
telemetry strip answers whether the machine is healthy. The sheet holds the work.

FIRST VIEWPORT
Show orientation, current condition, primary controls, and the opening dashboard
readings without a decorative hero or hidden navigation.

FORM
seed d2edd8ce

FINISH
unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
*/
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/chart_preferences.dart';
import '../models/card_workspace.dart';
import '../models/dashboard_preferences.dart';
import '../models/customization_preferences.dart';
import '../models/telemetry_sample.dart';
import '../models/telemetry_insights.dart';
import '../models/monitoring_lens.dart';
import '../models/session_journal.dart';
import '../../services/update_prompt_service.dart';
import '../../services/update_service.dart';
import '../utils/telemetry_chart.dart';
import '../services/desktop_integration_service.dart';
import '../services/companion_service.dart';
import '../services/gaming_overlay_controller.dart';
import '../widgets/hardware_skeleton.dart';
import '../widgets/metric_card.dart';
import '../widgets/metric_alert_action.dart';
import '../widgets/command_palette.dart';
import '../widgets/card_workspace.dart';
import '../widgets/dashboard_companion_widgets.dart';
import '../widgets/system_pulse_background.dart';
import '../widgets/telemetry_strip.dart';
import '../widgets/telemetry_studio.dart';
import '../widgets/startup_privacy_notice.dart';
import '../widgets/system_intelligence_hero.dart';
import '../widgets/session_journal_dialog.dart';
import 'pages/performance_page.dart';
import 'pages/gaming_page.dart';
import 'pages/processes_page.dart';
import 'pages/network_page.dart';
import 'pages/storage_page.dart';
import 'pages/optimization_page.dart';
import 'pages/reliability_page.dart';
import 'pages/benchmark_page.dart';
import 'pages/customization_page.dart';
import 'pages/settings_page.dart';
import 'pages/companion_page.dart';
import 'pages/plugins_page.dart';
import 'pages/bug_report_page.dart';
import '../services/telemetry_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/hardware_palette.dart';

class _NavigationDestination {
  final int index;
  final String label;
  final String shortcut;
  final IconData icon;

  const _NavigationDestination(
    this.index,
    this.label,
    this.shortcut,
    this.icon,
  );
}

class _NavigationGroup {
  final String label;
  final List<_NavigationDestination> destinations;

  const _NavigationGroup({required this.label, required this.destinations});
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _macOSMenuChannel = MethodChannel(
    'com.hardwaremon.HardwareMon/menu',
  );
  late TelemetryService telemetry;
  late ChartPreferences chartPreferences;
  late DashboardPreferences dashboardPreferences;
  late CustomizationPreferences customizationPreferences;
  late MonitoringLensPreferences monitoringLensPreferences;
  late SessionJournal sessionJournal;
  late CompanionService companionService;
  late CardWorkspacePreferences cardWorkspacePreferences;
  final gamingOverlay = GamingOverlayController.instance;
  StreamSubscription<DesktopCommand>? _desktopCommandSubscription;

  int selectedIndex = 0;
  int _previousIndex = 0;
  int _pageTransitionSerial = 0;

  static const _navigationGroups = <_NavigationGroup>[
    _NavigationGroup(
      label: 'Monitor',
      destinations: [
        _NavigationDestination(
          0,
          'Dashboard',
          'Alt+1',
          Icons.dashboard_rounded,
        ),
        _NavigationDestination(1, 'Processes', 'Alt+2', Icons.list_rounded),
        _NavigationDestination(
          2,
          'Performance',
          'Alt+3',
          Icons.analytics_rounded,
        ),
        _NavigationDestination(
          3,
          'Gaming',
          'Alt+G',
          Icons.sports_esports_rounded,
        ),
        _NavigationDestination(4, 'Network', 'Alt+4', Icons.language_rounded),
        _NavigationDestination(5, 'Storage', 'Alt+5', Icons.storage_rounded),
      ],
    ),
    _NavigationGroup(
      label: 'Tools',
      destinations: [
        _NavigationDestination(6, 'Maintenance', 'Alt+6', Icons.build_rounded),
        _NavigationDestination(
          7,
          'Reliability',
          'Alt+7',
          Icons.verified_rounded,
        ),
        _NavigationDestination(8, 'Benchmark', 'Alt+B', Icons.speed_rounded),
      ],
    ),
    _NavigationGroup(
      label: 'System',
      destinations: [
        _NavigationDestination(9, 'Customization', 'Alt+8', Icons.tune_rounded),
        _NavigationDestination(10, 'Settings', 'Alt+9', Icons.settings_rounded),
        _NavigationDestination(11, 'Companion', 'Ctrl+K', Icons.hub_rounded),
        _NavigationDestination(
          12,
          'Plugins',
          'Ctrl+K',
          Icons.extension_rounded,
        ),
      ],
    ),
  ];

  static const _pageTitles = <String>[
    'System overview',
    'Process register',
    'Performance history',
    'Gaming sessions',
    'Network activity',
    'Storage register',
    'Maintenance centre',
    'Reliability record',
    'Benchmark runs',
    'Appearance register',
    'Application settings',
    'Companion status',
    'Plugin register',
  ];

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _macOSMenuChannel.setMethodCallHandler(_handleMacOSMenuAction);
    }

    telemetry = TelemetryService();
    chartPreferences = ChartPreferences();
    dashboardPreferences = DashboardPreferences();
    customizationPreferences = CustomizationPreferences();
    monitoringLensPreferences = MonitoringLensPreferences();
    sessionJournal = SessionJournal();
    companionService = CompanionService(snapshotProvider: _liveSnapshot);
    cardWorkspacePreferences = CardWorkspacePreferences();

    telemetry.start();
    chartPreferences.load();
    dashboardPreferences.load();
    customizationPreferences.load();
    monitoringLensPreferences.load();
    sessionJournal.load();
    companionService.initialise();
    cardWorkspacePreferences.load();
    gamingOverlay.addListener(_overlayChanged);
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
    customizationPreferences.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    monitoringLensPreferences.addListener(() {
      if (mounted) setState(() {});
    });
    sessionJournal.addListener(() {
      if (mounted) setState(() {});
    });
    cardWorkspacePreferences.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(StartupPrivacyNotice.showIfRequired(context));
      final updateState = UpdateService.instance.state;
      if (updateState.stage == UpdateStage.complete ||
          updateState.stage == UpdateStage.failed) {
        UpdatePromptService.showStartupResult(context);
      } else {
        UpdatePromptService.checkAutomatically(context);
      }
    });
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _macOSMenuChannel.setMethodCallHandler(null);
    }
    _desktopCommandSubscription?.cancel();
    DesktopIntegrationService.instance.detachTelemetry(telemetry);
    telemetry.stop();
    chartPreferences.dispose();
    dashboardPreferences.dispose();
    customizationPreferences.dispose();
    monitoringLensPreferences.dispose();
    sessionJournal.dispose();
    companionService.dispose();
    cardWorkspacePreferences.dispose();
    gamingOverlay.removeListener(_overlayChanged);
    super.dispose();
  }

  void _overlayChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleMacOSMenuAction(MethodCall call) async {
    switch (call.method) {
      case 'openSettings':
        _selectPage(10);
        break;
      case 'refreshTelemetry':
        await telemetry.refreshNow(includeHistory: true);
        break;
    }
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
        _selectPage(10);
        break;
    }
  }

  void _selectPage(int index) {
    if (selectedIndex == index) return;
    setState(() {
      _previousIndex = selectedIndex;
      selectedIndex = index;
      _pageTransitionSerial++;
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
    cpuTemperature: telemetry.capabilities.supportsCpuTemperature
        ? telemetry.cpuTemp
        : null,
    gpuTemperature: telemetry.capabilities.supportsGpuTemperature
        ? telemetry.gpuTemp
        : null,
    paused: telemetry.isPaused,
    hasError: telemetry.lastError != null,
  );

  Map<String, Object?> _liveSnapshot() => {
    'cpu_usage': '${telemetry.cpuUsage}%',
    'cpu_temperature': telemetry.capabilities.supportsCpuTemperature
        ? '${telemetry.cpuTemp}°C'
        : null,
    'gpu_usage': telemetry.capabilities.supportsGpuUsage
        ? '${telemetry.gpuUsage}%'
        : null,
    'gpu_temperature': telemetry.capabilities.supportsGpuTemperature
        ? '${telemetry.gpuTemp}°C'
        : null,
    'ram_usage': '${telemetry.ramUsage}%',
    'storage_usage': '${telemetry.diskUsage}%',
    'cpu_power': telemetry.capabilities.supportsPowerMetrics
        ? '${telemetry.cpuPower.toStringAsFixed(1)} W'
        : null,
    'gpu_power': telemetry.capabilities.supportsPowerMetrics
        ? '${telemetry.gpuPower.toStringAsFixed(1)} W'
        : null,
    'status': _systemCondition.label,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  Future<void> _copySystemSnapshot() async {
    final capturedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final snapshot =
        '''
HardwareMon snapshot · $capturedAt
Status: ${_systemCondition.label}
CPU: ${telemetry.cpuUsage}% · ${telemetry.capabilities.supportsCpuTemperature ? '${telemetry.cpuTemp}°C' : telemetry.unavailableValue('cpu_temp')} · ${telemetry.capabilities.supportsCpuFrequency ? '${telemetry.cpuClockGHz.toStringAsFixed(2)} GHz' : telemetry.unavailableValue('cpu_clock')} · ${telemetry.capabilities.supportsPowerMetrics ? '${telemetry.cpuPower.toStringAsFixed(1)} W' : telemetry.unavailableValue('cpu_power')}
Memory: ${telemetry.ramUsage}% · ${telemetry.ramUsed.toStringAsFixed(1)} / ${telemetry.ramTotal.toStringAsFixed(1)} GB
GPU: ${telemetry.capabilities.supportsGpuUsage ? '${telemetry.gpuUsage}%' : telemetry.unavailableValue('gpu_usage')} · ${telemetry.capabilities.supportsGpuTemperature ? '${telemetry.gpuTemp}°C' : telemetry.unavailableValue('gpu_temp')} · ${telemetry.capabilities.supportsPowerMetrics ? '${telemetry.gpuPower.toStringAsFixed(1)} W' : telemetry.unavailableValue('gpu_power')}
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

  Future<void> _captureSessionSnapshot(SystemHealthProfile profile) async {
    await sessionJournal.capture(
      profile: profile,
      lens: monitoringLensPreferences.lens,
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session saved · ${profile.overallScore}/100 · ${monitoringLensPreferences.lens.label}',
        ),
        action: SnackBarAction(
          label: 'Open journal',
          onPressed: () => showSessionJournalDialog(
            context: context,
            journal: sessionJournal,
          ),
        ),
      ),
    );
  }

  Future<void> _captureCurrentSessionSnapshot() {
    final summary = buildTelemetrySessionSummary(
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuHistory: telemetry.cpuHistory,
      ramHistory: telemetry.ramHistory,
      gpuHistory: telemetry.gpuUsageHistory,
      cpuTemperatureHistory: telemetry.cpuTempHistory,
      gpuTemperatureHistory: telemetry.gpuTempHistory,
      since: telemetry.sessionStatisticsStartedAt,
      paused: telemetry.isPaused,
      lastError: telemetry.lastError,
    );
    final profile = buildSystemHealthProfile(
      summary: summary,
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuPower: telemetry.cpuPower,
      gpuPower: telemetry.gpuPower,
      lens: monitoringLensPreferences.lens,
      paused: telemetry.isPaused,
      hasError: telemetry.lastError != null,
    );
    return _captureSessionSnapshot(profile);
  }

  Future<void> _showKeyboardShortcuts() {
    const shortcuts = [
      ('Command palette', 'Ctrl K'),
      ('Navigate pages', 'Alt 1–9'),
      ('Open Gaming', 'Alt G'),
      ('Open Benchmark', 'Alt B'),
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
        id: 'gaming',
        title: 'Open Gaming',
        description: 'Review live game detection, sessions, and gaming history',
        section: 'Navigate',
        shortcut: 'Alt G',
        icon: Icons.sports_esports_rounded,
        selected: selectedIndex == 3,
        keywords: const [
          'game',
          'gaming',
          'session',
          'minecraft',
          'steam',
          'gpu',
        ],
        run: () => _selectPage(3),
      ),
      CommandPaletteAction(
        id: 'network',
        title: 'Open Network',
        description: 'Inspect adapters, bandwidth, and test endpoints',
        section: 'Navigate',
        shortcut: 'Alt 4',
        icon: Icons.language_rounded,
        selected: selectedIndex == 4,
        keywords: const ['ping', 'adapter', 'bandwidth', 'latency'],
        run: () => _selectPage(4),
      ),
      CommandPaletteAction(
        id: 'storage',
        title: 'Open Storage',
        description: 'Inspect drives, capacity, health, usage, and performance',
        section: 'Navigate',
        shortcut: 'Alt 5',
        icon: Icons.storage_rounded,
        selected: selectedIndex == 5,
        keywords: const [
          'disk',
          'drive',
          'capacity',
          'smart',
          'benchmark',
          'space',
        ],
        run: () => _selectPage(5),
      ),
      CommandPaletteAction(
        id: 'optimization',
        title: 'Open Maintenance Centre',
        description:
            'Review system upkeep, health evidence, and recommendations',
        section: 'Navigate',
        shortcut: 'Alt 6',
        icon: Icons.auto_awesome_rounded,
        selected: selectedIndex == 6,
        keywords: const [
          'health',
          'startup',
          'cleanup',
          'memory',
          'thermal',
          'gaming',
        ],
        run: () => _selectPage(6),
      ),
      CommandPaletteAction(
        id: 'reliability',
        title: 'Open Reliability',
        description: 'Review stability score, active risks, and recovery steps',
        section: 'Navigate',
        shortcut: 'Alt 7',
        icon: Icons.verified_rounded,
        selected: selectedIndex == 7,
        keywords: const [
          'stability',
          'health',
          'incidents',
          'risk',
          'runbook',
          'timeline',
        ],
        run: () => _selectPage(7),
      ),
      CommandPaletteAction(
        id: 'benchmark',
        title: 'Open Benchmark',
        description: 'Run safe local CPU, memory, and disk performance tests',
        section: 'Navigate',
        shortcut: 'Alt B',
        icon: Icons.speed_rounded,
        selected: selectedIndex == 8,
        keywords: const [
          'score',
          'performance',
          'cpu',
          'memory',
          'disk',
          'test',
        ],
        run: () => _selectPage(8),
      ),
      CommandPaletteAction(
        id: 'customization',
        title: 'Open Customization',
        description: 'Personalize layouts, themes, motion, and profiles',
        section: 'Navigate',
        shortcut: 'Alt 8',
        icon: Icons.palette_rounded,
        selected: selectedIndex == 9,
        keywords: const [
          'theme',
          'accent',
          'layout',
          'sidebar',
          'profile',
          'widgets',
        ],
        run: () => _selectPage(9),
      ),
      CommandPaletteAction(
        id: 'settings',
        title: 'Open Settings',
        description: 'Configure monitoring and desktop behaviour',
        section: 'Navigate',
        shortcut: 'Alt 9',
        icon: Icons.settings_rounded,
        selected: selectedIndex == 10,
        keywords: const ['preferences', 'configure'],
        run: () => _selectPage(10),
      ),
      CommandPaletteAction(
        id: 'companion-centre',
        title: 'Open Companion Centre',
        description: 'Share, export, pair devices, and inspect extensions',
        section: 'Navigate',
        icon: Icons.hub_rounded,
        selected: selectedIndex == 11,
        keywords: const [
          'snapshot',
          'inventory',
          'export',
          'web dashboard',
          'qr',
          'portable',
          'plugins',
          'widgets',
        ],
        run: () => _selectPage(11),
      ),
      CommandPaletteAction(
        id: 'plugin-studio',
        title: 'Open Plugin Studio',
        description: 'Manage extensions, permissions, health, and logs',
        section: 'Navigate',
        icon: Icons.extension_rounded,
        selected: selectedIndex == 12,
        keywords: const [
          'plugin',
          'extension',
          'prometheus',
          'developer',
          'permissions',
          'capabilities',
        ],
        run: () => _selectPage(12),
      ),
      CommandPaletteAction(
        id: 'saved-card-layouts',
        title: 'Manage Saved Card Layouts',
        description: 'Save, apply, or delete app-wide card configurations',
        section: 'Appearance',
        icon: Icons.bookmarks_rounded,
        keywords: const [
          'cards',
          'layout',
          'reorder',
          'resize',
          'hidden',
          'workspace',
        ],
        run: () => showCardLayoutsDialog(
          context: context,
          preferences: cardWorkspacePreferences,
        ),
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
      for (final lens in MonitoringLens.values)
        CommandPaletteAction(
          id: 'monitoring-lens-${lens.name}',
          title: 'Use ${lens.label} Monitoring Lens',
          description: lens.description,
          section: 'Monitoring lens',
          icon: Icons.filter_center_focus_rounded,
          selected: monitoringLensPreferences.lens == lens,
          keywords: const ['health', 'score', 'focus', 'interpretation'],
          run: () => monitoringLensPreferences.setLens(lens),
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
        id: 'save-session-snapshot',
        title: 'Save Session Snapshot',
        description: 'Capture the current health score and metrics locally',
        section: 'Quick actions',
        icon: Icons.bookmark_add_rounded,
        keywords: const ['journal', 'bookmark', 'baseline', 'capture'],
        run: _captureCurrentSessionSnapshot,
      ),
      CommandPaletteAction(
        id: 'open-session-journal',
        title: 'Open Session Journal',
        description: '${sessionJournal.entries.length} private snapshots saved',
        section: 'Quick actions',
        icon: Icons.bookmarks_rounded,
        keywords: const ['history', 'snapshots', 'baseline', 'compare'],
        run: () =>
            showSessionJournalDialog(context: context, journal: sessionJournal),
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
        id: 'report-bug',
        title: 'Report a Bug',
        description: 'Send feedback with privacy-controlled diagnostics',
        section: 'Help',
        icon: Icons.bug_report_rounded,
        keywords: const ['crash', 'error', 'feedback', 'support'],
        run: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BugReportPage(
              onShowPending: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PendingReportsPage(),
                ),
              ),
            ),
          ),
        ),
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
    final gpuSummary = telemetry.capabilities.supportsGpuTemperature
        ? 'GPU ${telemetry.gpuTemp}°'
        : 'GPU sensors unavailable';
    final telemetrySummary =
        'CPU ${telemetry.cpuUsage}%  ·  RAM ${telemetry.ramUsage}%  ·  $gpuSummary';
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
    final sessionSummary = buildTelemetrySessionSummary(
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuHistory: telemetry.cpuHistory,
      ramHistory: telemetry.ramHistory,
      gpuHistory: telemetry.gpuUsageHistory,
      cpuTemperatureHistory: telemetry.cpuTempHistory,
      gpuTemperatureHistory: telemetry.gpuTempHistory,
      since: telemetry.sessionStatisticsStartedAt,
      paused: telemetry.isPaused,
      lastError: telemetry.lastError,
    );
    final healthProfile = buildSystemHealthProfile(
      summary: sessionSummary,
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuPower: telemetry.cpuPower,
      gpuPower: telemetry.gpuPower,
      lens: monitoringLensPreferences.lens,
      paused: telemetry.isPaused,
      hasError: telemetry.lastError != null,
    );
    final connecting =
        telemetry.lastUpdated == null && telemetry.lastError == null;
    final cards = <WorkspaceCard>[
      for (var index = 0; index < metrics.length; index++)
        WorkspaceCard(
          id: metrics[index].id.name,
          title: metrics[index].title,
          child: connecting
              ? HardwareSkeletonCard(key: ValueKey('dashboard-skeleton-$index'))
              : _buildDashboardMetricCard(metrics[index], index),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          key: const PageStorageKey('hardwaremon-dashboard-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SystemIntelligenceHero(
                  profile: healthProfile,
                  lens: monitoringLensPreferences.lens,
                  onLensChanged: monitoringLensPreferences.setLens,
                  onOpenPerformance: () => _selectPage(2),
                  onOpenProcesses: () => _selectPage(1),
                  onSaveSnapshot: () => _captureSessionSnapshot(healthProfile),
                  onOpenJournal: () => showSessionJournalDialog(
                    context: context,
                    journal: sessionJournal,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DashboardWorkspaceSelector(
                  selected: dashboardPreferences.workspace,
                  onSelected: _applyDashboardWorkspace,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: CardWorkspace(
                pageId: 'dashboard-${dashboardPreferences.workspace.name}',
                pageLabel: 'Dashboard',
                preferences: cardWorkspacePreferences,
                cards: cards,
                standardHeight: dashboardPreferences.cardSize.height,
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardCompanionWidgets(
                telemetry: telemetry,
                preferences: customizationPreferences,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
      hoverEffects: customizationPreferences.hoverEffects,
      transitionDuration: customizationPreferences.transitionDuration,
    );

    if (!chartPreferences.animations ||
        !customizationPreferences.animationsEnabled) {
      return card;
    }

    return card
        .animate(key: ValueKey('${dashboardPreferences.workspace.name}-$index'))
        .fadeIn(
          delay: Duration(milliseconds: index * 90),
          duration: customizationPreferences.transitionDuration,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          delay: Duration(milliseconds: index * 90),
          duration: customizationPreferences.transitionDuration,
          curve: Curves.easeOutCubic,
        );
  }

  List<_DashboardMetric> _dashboardMetrics(DashboardWorkspace workspace) {
    final cpuUsage = _DashboardMetric(
      id: DashboardMetricId.cpuUsage,
      title: 'CPU Usage',
      value: '${telemetry.cpuUsage}%',
      subtitle: telemetry.cpuName,
      icon: Icons.memory_rounded,
      accent: HardwareDomain.cpu.color,
      samples: telemetry.cpuHistory,
      alertKind: MetricAlertKind.cpuUsage,
      alertValue: telemetry.cpuUsage.toDouble(),
    );
    final memory = _DashboardMetric(
      id: DashboardMetricId.memory,
      title: 'Memory',
      value: '${telemetry.ramUsage}%',
      subtitle: 'System memory usage',
      icon: Icons.storage_rounded,
      accent: HardwareDomain.memory.color,
      samples: telemetry.ramHistory,
      alertKind: MetricAlertKind.ramUsage,
      alertValue: telemetry.ramUsage.toDouble(),
    );
    final gpuUsage = _DashboardMetric(
      id: DashboardMetricId.gpuUsage,
      title: 'GPU Usage',
      value: '${telemetry.gpuUsage}%',
      subtitle: 'Graphics workload',
      icon: Icons.show_chart_rounded,
      accent: HardwareDomain.gpu.color,
      samples: telemetry.gpuUsageHistory,
    );
    final cpuTemperature = _DashboardMetric(
      id: DashboardMetricId.cpuTemperature,
      title: 'CPU Temp',
      value: telemetry.capabilities.supportsCpuTemperature
          ? '${telemetry.cpuTemp}°'
          : telemetry.unavailableValue('cpu_temp'),
      subtitle: telemetry.capabilities.supportsCpuTemperature
          ? 'Package temperature'
          : telemetry.unavailableReason('cpu_temp'),
      icon: Icons.thermostat_rounded,
      accent: HardwareDomain.thermal.color,
      samples: telemetry.cpuTempHistory,
      metricKind: TelemetryMetricKind.temperature,
      alertKind: MetricAlertKind.cpuTemperature,
      alertValue: telemetry.cpuTemp.toDouble(),
    );
    final gpuTemperature = _DashboardMetric(
      id: DashboardMetricId.gpuTemperature,
      title: 'GPU Temp',
      value: telemetry.capabilities.supportsGpuTemperature
          ? '${telemetry.gpuTemp}°'
          : telemetry.unavailableValue('gpu_temp'),
      subtitle: telemetry.capabilities.supportsGpuTemperature
          ? 'Graphics temperature'
          : telemetry.unavailableReason('gpu_temp'),
      icon: Icons.graphic_eq_rounded,
      accent: HardwareDomain.thermal.color,
      samples: telemetry.gpuTempHistory,
      metricKind: TelemetryMetricKind.temperature,
      alertKind: MetricAlertKind.gpuTemperature,
      alertValue: telemetry.gpuTemp.toDouble(),
    );
    final cpuPower = _DashboardMetric(
      id: DashboardMetricId.cpuPower,
      title: 'CPU Power',
      value: telemetry.capabilities.supportsPowerMetrics
          ? '${telemetry.cpuPower.toStringAsFixed(1)} W'
          : telemetry.unavailableValue('cpu_power'),
      subtitle: telemetry.capabilities.supportsPowerMetrics
          ? 'Package power draw'
          : telemetry.unavailableReason('cpu_power'),
      icon: Icons.bolt_rounded,
      accent: HardwareDomain.power.color,
      samples: telemetry.cpuPowerHistory,
      metricKind: TelemetryMetricKind.watts,
    );
    final gpuPower = _DashboardMetric(
      id: DashboardMetricId.gpuPower,
      title: 'GPU Power',
      value: telemetry.capabilities.supportsPowerMetrics
          ? '${telemetry.gpuPower.toStringAsFixed(1)} W'
          : telemetry.unavailableValue('gpu_power'),
      subtitle: telemetry.capabilities.supportsPowerMetrics
          ? 'Board power draw'
          : telemetry.unavailableReason('gpu_power'),
      icon: Icons.electric_bolt_rounded,
      accent: HardwareDomain.power.color,
      samples: telemetry.gpuPowerHistory,
      metricKind: TelemetryMetricKind.watts,
    );

    final workspaceMetrics = switch (workspace) {
      DashboardWorkspace.overview => [
        cpuUsage,
        memory,
        if (telemetry.capabilities.supportsGpuTemperature) gpuTemperature,
      ],
      DashboardWorkspace.workload => [
        cpuUsage,
        if (telemetry.capabilities.supportsGpuUsage) gpuUsage,
        memory,
      ],
      DashboardWorkspace.thermals => [
        if (telemetry.capabilities.supportsCpuTemperature) cpuTemperature,
        if (telemetry.capabilities.supportsGpuTemperature) gpuTemperature,
        if (telemetry.capabilities.supportsPowerMetrics) cpuPower,
      ],
      DashboardWorkspace.power => [
        if (telemetry.capabilities.supportsPowerMetrics) cpuPower,
        if (telemetry.capabilities.supportsPowerMetrics) gpuPower,
        if (telemetry.capabilities.supportsGpuUsage) gpuUsage,
      ],
    };
    if (workspaceMetrics.isEmpty) return [cpuUsage, memory];
    final byId = {for (final metric in workspaceMetrics) metric.id: metric};
    return dashboardPreferences
        .orderedVisible(byId.keys)
        .map((id) => byId[id]!)
        .toList(growable: false);
  }

  Widget getCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return buildDashboard();

      case 1:
        return ProcessesPage(capabilities: telemetry.capabilities);

      case 2:
        return PerformancePage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
          cardWorkspacePreferences: cardWorkspacePreferences,
        );

      case 3:
        return GamingPage(cardWorkspacePreferences: cardWorkspacePreferences);

      case 4:
        return NetworkPage(cardWorkspacePreferences: cardWorkspacePreferences);

      case 5:
        return StoragePage(cardWorkspacePreferences: cardWorkspacePreferences);

      case 6:
        return OptimizationPage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
          onOpenProcesses: () => _selectPage(1),
          onOpenStorage: () => _selectPage(5),
          cardWorkspacePreferences: cardWorkspacePreferences,
        );

      case 7:
        return ReliabilityPage(
          telemetry: telemetry,
          onOpenPerformance: () => _selectPage(2),
          onOpenProcesses: () => _selectPage(1),
          onOpenStorage: () => _selectPage(5),
          onOpenNetwork: () => _selectPage(4),
          cardWorkspacePreferences: cardWorkspacePreferences,
        );

      case 8:
        return BenchmarkPage(
          cardWorkspacePreferences: cardWorkspacePreferences,
        );

      case 9:
        return CustomizationPage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
          dashboardPreferences: dashboardPreferences,
          customizationPreferences: customizationPreferences,
        );

      case 10:
        return SettingsPage(
          telemetry: telemetry,
          chartPreferences: chartPreferences,
          dashboardPreferences: dashboardPreferences,
          customizationPreferences: customizationPreferences,
        );

      case 11:
        return CompanionPage(
          telemetry: telemetry,
          service: companionService,
          cardWorkspacePreferences: cardWorkspacePreferences,
        );

      case 12:
        return PluginsPage(
          service: companionService,
          cardWorkspacePreferences: cardWorkspacePreferences,
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

  Widget _buildNavigationRail(BuildContext context) {
    final expanded =
        customizationPreferences.showSidebarLabels ||
        customizationPreferences.sidebarMode == SidebarMode.expanded ||
        customizationPreferences.sidebarWidth >= 150;
    final width = expanded
        ? customizationPreferences.sidebarWidth.clamp(176.0, 228.0)
        : customizationPreferences.sidebarWidth.clamp(68.0, 92.0);

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: AppColors.rail(context),
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.memory_rounded,
                      color: Color(0xFFF0F1ED),
                      size: 24,
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Text(
                        'HardwareMon',
                        style: AppTypography.heading.copyWith(
                          color: const Color(0xFFF0F1ED),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in _navigationGroups) ...[
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 13, 12, 7),
                          child: Text(
                            group.label,
                            style: AppTypography.sectionLabel.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      for (final destination in group.destinations)
                        _DockItem(
                          icon: destination.icon,
                          label: destination.label,
                          shortcut: destination.shortcut,
                          active: selectedIndex == destination.index,
                          onTap: () => _selectPage(destination.index),
                          showLabel: expanded,
                          iconSize: customizationPreferences.sidebarIconSize
                              .clamp(17, 24),
                          hoverEffects: customizationPreferences.hoverEffects,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
            Tooltip(
              message: 'Quick actions  •  Ctrl+K',
              child: Semantics(
                button: true,
                label: 'Quick actions',
                child: InkWell(
                  onTap: _showCommandPalette,
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        if (expanded) const SizedBox(width: 18),
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFFD4DAD8),
                        ),
                        if (expanded) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Quick actions',
                            style: AppTypography.body.copyWith(
                              color: const Color(0xFFD4DAD8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.rule(context))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            _pageTitles[selectedIndex],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: constraints.maxWidth < 760 ? 25 : 29,
            ),
          );
          if (constraints.maxWidth < 840) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
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
              Expanded(child: title),
              const SizedBox(width: 18),
              controls,
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceBinderBody(BuildContext context) {
    return ColoredBox(
      color: AppColors.frame(context),
      child: Stack(
        children: [
          SystemPulseBackground(
            cpuUsage: telemetry.cpuUsage,
            ramUsage: telemetry.ramUsage,
            gpuTemperature: telemetry.gpuTemp,
            enabled: chartPreferences.ambientEffects,
            intensity: customizationPreferences.ambientGlowIntensity,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 26,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildNavigationRail(context),
                    Container(width: 1, color: AppColors.rule(context)),
                    Expanded(
                      child: ColoredBox(
                        color: AppColors.background(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(context),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: chartPreferences.telemetryTicker
                                  ? TelemetryStrip(
                                      key: const ValueKey(
                                        'telemetry-strip-visible',
                                      ),
                                      cpuUsage: telemetry.cpuUsage,
                                      cpuTemperature:
                                          telemetry
                                              .capabilities
                                              .supportsCpuTemperature
                                          ? telemetry.cpuTemp
                                          : null,
                                      ramUsage: telemetry.ramUsage,
                                      gpuUsage:
                                          telemetry
                                              .capabilities
                                              .supportsGpuUsage
                                          ? telemetry.gpuUsage
                                          : null,
                                      gpuTemperature:
                                          telemetry
                                              .capabilities
                                              .supportsGpuTemperature
                                          ? telemetry.gpuTemp
                                          : null,
                                      diskUsage: telemetry.diskUsage,
                                      paused: telemetry.isPaused,
                                      hasError: telemetry.lastError != null,
                                      onOpenPerformance: () => _selectPage(2),
                                      onCopySnapshot: _copySystemSnapshot,
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('telemetry-strip-hidden'),
                                    ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  16,
                                  18,
                                  18,
                                ),
                                child: ClipRect(
                                  child: AnimatedSwitcher(
                                    duration:
                                        chartPreferences.animations &&
                                            customizationPreferences
                                                .animationsEnabled
                                        ? customizationPreferences
                                              .transitionDuration
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
                                            begin: Offset(0.012 * direction, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey(
                                        '$selectedIndex-$_pageTransitionSerial',
                                      ),
                                      child: getCurrentPage(),
                                    ),
                                  ),
                                ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (gamingOverlay.visible) {
      return _InGameOverlay(telemetry: telemetry, controller: gamingOverlay);
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
            _selectPage(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
            _selectPage(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
            _selectPage(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
            _selectPage(4),
        const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () =>
            _selectPage(5),
        const SingleActivator(LogicalKeyboardKey.digit6, alt: true): () =>
            _selectPage(6),
        const SingleActivator(LogicalKeyboardKey.digit7, alt: true): () =>
            _selectPage(7),
        const SingleActivator(LogicalKeyboardKey.digit8, alt: true): () =>
            _selectPage(9),
        const SingleActivator(LogicalKeyboardKey.digit9, alt: true): () =>
            _selectPage(10),
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () =>
            _selectPage(8),
        const SingleActivator(LogicalKeyboardKey.keyG, alt: true): () =>
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
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
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
            _selectPage(10),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            _selectPage(10),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(body: _buildServiceBinderBody(context)),
      ),
    );
  }
}

class _InGameOverlay extends StatelessWidget {
  const _InGameOverlay({required this.telemetry, required this.controller});

  final TelemetryService telemetry;
  final GamingOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, Color)>[
      ('FPS', 'Provider unavailable', Colors.white70),
      ('CPU', '${telemetry.cpuUsage}%', AppColors.accent),
      ('GPU', '${telemetry.gpuUsage}%', Colors.purpleAccent),
      ('RAM', '${telemetry.ramUsage}%', Colors.lightGreenAccent),
      (
        'CPU',
        telemetry.cpuTemp > 0 ? '${telemetry.cpuTemp}°C' : '—',
        Colors.orangeAccent,
      ),
      (
        'GPU',
        telemetry.gpuTemp > 0 ? '${telemetry.gpuTemp}°C' : '—',
        Colors.redAccent,
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanStart: controller.interactionMode ? (_) {} : null,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xED090D13),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent.withValues(alpha: .45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .45),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'HARDWAREMON  ·  GAME OVERLAY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Text(
                    GamingOverlayController.toggleShortcutLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  if (controller.interactionMode) ...[
                    const SizedBox(width: 5),
                    IconButton(
                      onPressed: controller.hide,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Wrap(
                  spacing: 15,
                  runSpacing: 7,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: metric.$1 == 'FPS' ? 112 : 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              metric.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metric.$3,
                                fontSize: metric.$1 == 'FPS' ? 11 : 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              metric.$1,
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric {
  final DashboardMetricId id;
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
    required this.id,
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

// Kept as the fallback used by older dashboard workspace integrations.
// ignore: unused_element
class _DashboardEmptyState extends StatelessWidget {
  final VoidCallback onRestore;

  const _DashboardEmptyState({required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This workspace is yours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              'Every metric card is currently hidden. Restore the curated layout, then refine it in Customization.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Restore curated layout'),
            ),
          ],
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(6),
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
  final bool showLabel;
  final double iconSize;
  final bool hoverEffects;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
    this.active = false,
    this.showLabel = false,
    this.iconSize = 24,
    this.hoverEffects = true,
  });

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool hovering = false;
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFF5F1E8);
    final inactiveColor = Colors.white.withValues(alpha: 0.72);
    final interactive = widget.active || hovering || focused;

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
                duration: Duration(
                  milliseconds:
                      (150 * AppColors.sidebarMotionIntensity.clamp(0.1, 1.5))
                          .round(),
                ),
                width: widget.showLabel ? 228 : 92,
                height: 42,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.showLabel ? 14 : 0,
                ),
                decoration: BoxDecoration(
                  color: interactive
                      ? Colors.white.withValues(
                          alpha: widget.active ? 0.12 : 0.065,
                        )
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: widget.active
                          ? AppColors.workOrderBlue
                          : focused
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: widget.showLabel
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: widget.active ? activeColor : inactiveColor,
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: widget.active ? activeColor : inactiveColor,
                            fontSize: 12,
                            fontWeight: widget.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.active)
                        CustomPaint(
                          size: const Size(11, 13),
                          painter: _IndexNotchPainter(
                            color: AppColors.workOrderBlue,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexNotchPainter extends CustomPainter {
  final Color color;

  const _IndexNotchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height * 0.65)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IndexNotchPainter oldDelegate) =>
      oldDelegate.color != color;
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
            duration: const Duration(milliseconds: 140),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _hovering
                  ? AppColors.workOrderBlue.withValues(alpha: 0.12)
                  : AppColors.controlFill(context),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _hovering
                    ? AppColors.workOrderBlue.withValues(alpha: 0.5)
                    : AppColors.rule(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: _hovering
                      ? AppColors.workOrderBlue
                      : AppColors.textSecondary(context),
                ),
                const SizedBox(width: 7),
                Text(
                  'Quick actions',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
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
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.rule(context)),
      ),
      child: Text(
        label,
        style: AppTypography.metadata.copyWith(
          color: AppColors.textMuted(context),
          fontSize: 8,
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
        ? AppColors.warningRed
        : paused
        ? const Color(0xFF987126)
        : AppColors.healthyGreen;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.controlFill(context),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.rule(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 3, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 10,
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
                ? AppColors.workOrderBlue.withValues(alpha: 0.14)
                : AppColors.controlFill(context),
            foregroundColor: active
                ? AppColors.workOrderBlue
                : AppColors.textSecondary(context),
            disabledForegroundColor: AppColors.textMuted(context),
            minimumSize: const Size(34, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: BorderSide(
                color: active
                    ? AppColors.workOrderBlue.withValues(alpha: 0.5)
                    : AppColors.rule(context),
              ),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 17),
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
              'WORKSPACE',
              style: AppTypography.sectionLabel.copyWith(
                color: AppColors.textMuted(context),
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
              style: AppTypography.sectionLabel.copyWith(
                color: AppColors.textMuted(context),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.controlFill(context),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AppColors.rule(context)),
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
