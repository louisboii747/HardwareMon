import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/chart_preferences.dart';
import '../utils/telemetry_chart.dart';
import '../widgets/glass_panel.dart';
import '../widgets/metric_card.dart';
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

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    telemetry = TelemetryService();
    chartPreferences = ChartPreferences();

    telemetry.start();
    chartPreferences.load();

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
  }

  @override
  void dispose() {
    telemetry.stop();
    chartPreferences.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (selectedIndex == index) return;
    setState(() => selectedIndex = index);
  }

  Widget buildDashboard() {
    final cpuCard =
        MetricCard(
              title: 'CPU Usage',
              value: '${telemetry.cpuUsage}%',
              subtitle: telemetry.cpuName,
              icon: Icons.memory_rounded,
              accent: Colors.cyan,
              graphPoints: telemetry.cpuHistory,
              chartPreferences: chartPreferences,
            )
            .animate()
            .fadeIn(duration: 700.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.08,
              end: 0,
              duration: 700.ms,
              curve: Curves.easeOutCubic,
            );
    final memoryCard =
        MetricCard(
              title: 'Memory',
              value: '${telemetry.ramUsage}%',
              subtitle: 'System memory usage',
              icon: Icons.storage_rounded,
              accent: Colors.purple,
              graphPoints: telemetry.ramHistory,
              chartPreferences: chartPreferences,
            )
            .animate()
            .fadeIn(delay: 120.ms, duration: 700.ms)
            .slideY(
              begin: 0.08,
              end: 0,
              duration: 700.ms,
              curve: Curves.easeOutCubic,
            );
    final gpuCard =
        MetricCard(
              title: 'GPU Temp',
              value: '${telemetry.gpuTemp}°',
              subtitle: 'Live telemetry',
              icon: Icons.graphic_eq_rounded,
              accent: Colors.orange,
              graphPoints: telemetry.gpuTempHistory,
              chartPreferences: chartPreferences,
              metricKind: TelemetryMetricKind.temperature,
            )
            .animate()
            .fadeIn(delay: 220.ms, duration: 700.ms)
            .slideY(
              begin: 0.08,
              end: 0,
              duration: 700.ms,
              curve: Curves.easeOutCubic,
            );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 300, child: cpuCard),
                const SizedBox(height: 16),
                SizedBox(height: 250, child: memoryCard),
                const SizedBox(height: 16),
                SizedBox(height: 250, child: gpuCard),
              ],
            ),
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: cpuCard),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: memoryCard),
                  const SizedBox(height: 24),
                  Expanded(child: gpuCard),
                ],
              ),
            ),
          ],
        );
      },
    );
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
        return SettingsPage(telemetry: telemetry);

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
              controls,
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
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            telemetry.togglePaused(),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            telemetry.refreshNow(includeHistory: true),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
            _toggleChartPreference(ChartPreference.gridLines),
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () =>
            _toggleChartPreference(ChartPreference.animations),
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
                Positioned(
                  top: -120,
                  left: -120,

                  child: Container(
                    width: 400,
                    height: 400,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      gradient: RadialGradient(
                        colors: [
                          Colors.cyan.withValues(
                            alpha: AppColors.isLight(context) ? 0.12 : 0.08,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
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

                              const SizedBox(height: 32),

                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 450),

                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeOutCubic,

                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,

                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.03, 0),
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
      message: 'Chart display options',
      child: PopupMenuButton<ChartPreference>(
        tooltip: '',
        onSelected: onSelected,
        color: AppColors.surfaceElevated(context),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
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
