import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chart_preferences.dart';
import '../../utils/telemetry_chart.dart';
import '../../widgets/metric_card.dart';

class PerformancePage extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;

  const PerformancePage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a card for details. Sections and cards support mouse, Tab, Enter, and Space.',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _PerformanceControls(
            telemetry: telemetry,
            chartPreferences: chartPreferences,
          ),
          const SizedBox(height: 24),
          _PerformanceSection(
            title: 'CPU',
            icon: Icons.memory_rounded,
            accent: Colors.cyan,
            cards: [
              MetricCard(
                title: 'CPU Usage',
                value: '${telemetry.cpuUsage}%',
                subtitle: telemetry.cpuName,
                icon: Icons.memory_rounded,
                accent: Colors.cyan,
                graphPoints: telemetry.cpuHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'CPU Temperature',
                value: '${telemetry.cpuTemp}°C',
                subtitle: 'CPU Package Temperature',
                icon: Icons.thermostat_rounded,
                accent: Colors.red,
                graphPoints: telemetry.cpuTempHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.temperature,
              ),
              MetricCard(
                title: 'CPU Clock',
                value: '${telemetry.cpuClockGHz.toStringAsFixed(2)} GHz',
                subtitle: 'Current clock speed',
                icon: Icons.speed_rounded,
                accent: Colors.green,
                graphPoints: telemetry.cpuClockHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigahertz,
              ),
              MetricCard(
                title: 'CPU Power',
                value: '${telemetry.cpuPower.toStringAsFixed(1)} W',
                subtitle: 'Package power draw',
                icon: Icons.bolt_rounded,
                accent: Colors.amber,
                graphPoints: telemetry.cpuPowerHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.watts,
              ),
            ],
          ),
          _PerformanceSection(
            title: 'Memory',
            icon: Icons.storage_rounded,
            accent: Colors.purple,
            cards: [
              MetricCard(
                title: 'RAM Usage',
                value: '${telemetry.ramUsage}%',
                subtitle: 'System memory usage',
                icon: Icons.storage_rounded,
                accent: Colors.purple,
                graphPoints: telemetry.ramHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'RAM Used',
                value: '${telemetry.ramUsed.toStringAsFixed(1)} GB',
                subtitle: 'Currently allocated',
                icon: Icons.memory_rounded,
                accent: Colors.teal,
                graphPoints: telemetry.ramUsedHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
              ),
              MetricCard(
                title: 'RAM Available',
                value: '${telemetry.ramAvailable.toStringAsFixed(1)} GB',
                subtitle: 'Available memory',
                icon: Icons.check_circle_outline_rounded,
                accent: Colors.lightGreen,
                graphPoints: telemetry.ramAvailableHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
              ),
              MetricCard(
                title: 'Total RAM',
                value: '${telemetry.ramTotal.toStringAsFixed(1)} GB',
                subtitle: 'Installed memory',
                icon: Icons.dns_rounded,
                accent: Colors.indigo,
                graphPoints: telemetry.ramTotalHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
              ),
            ],
          ),
          _PerformanceSection(
            title: 'GPU',
            icon: Icons.graphic_eq_rounded,
            accent: Colors.orange,
            cards: [
              MetricCard(
                title: 'GPU Temperature',
                value: '${telemetry.gpuTemp}°C',
                subtitle: 'Live telemetry',
                icon: Icons.graphic_eq_rounded,
                accent: Colors.orange,
                graphPoints: telemetry.gpuTempHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.temperature,
              ),
              MetricCard(
                title: 'GPU Usage',
                value: '${telemetry.gpuUsage}%',
                subtitle: 'Current GPU load',
                icon: Icons.show_chart_rounded,
                accent: Colors.blue,
                graphPoints: telemetry.gpuUsageHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'GPU Power',
                value: '${telemetry.gpuPower.toStringAsFixed(1)} W',
                subtitle: 'Board power draw',
                icon: Icons.bolt_rounded,
                accent: const Color.fromARGB(255, 115, 255, 0),
                graphPoints: telemetry.gpuPowerHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.watts,
              ),
              MetricCard(
                title: 'VRAM Used',
                value: '${telemetry.gpuVramUsed.toStringAsFixed(1)} GB',
                subtitle: 'Graphics memory usage',
                icon: Icons.memory_rounded,
                accent: Colors.purple,
                graphPoints: telemetry.gpuVramUsedHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
              ),
            ],
          ),
          _PerformanceSection(
            title: 'Historical Analytics',
            icon: Icons.timeline_rounded,
            accent: AppColors.accent,
            preferredColumns: 3,
            cards: [
              MetricCard(
                title: 'CPU History',
                value: '${telemetry.historicalCpuHistory.length}',
                subtitle: 'Timestamped samples',
                icon: Icons.timeline_rounded,
                accent: Colors.cyan,
                graphPoints: telemetry.historicalCpuHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'Memory History',
                value: '${telemetry.historicalRamHistory.length}',
                subtitle: 'Timestamped samples',
                icon: Icons.storage_rounded,
                accent: Colors.purple,
                graphPoints: telemetry.historicalRamHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'GPU History',
                value: '${telemetry.historicalGpuHistory.length}',
                subtitle: 'Timestamped samples',
                icon: Icons.graphic_eq_rounded,
                accent: Colors.orange,
                graphPoints: telemetry.historicalGpuHistory,
                chartPreferences: chartPreferences,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceControls extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;

  const _PerformanceControls({
    required this.telemetry,
    required this.chartPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _PreferenceSwitch(
            label: 'Live',
            icon: telemetry.isPaused
                ? Icons.pause_circle_outline_rounded
                : Icons.sensors_rounded,
            value: !telemetry.isPaused,
            onChanged: (value) => telemetry.setPaused(!value),
          ),
          _PreferenceSwitch(
            label: 'Smooth curves',
            icon: Icons.gesture_rounded,
            value: chartPreferences.smoothLines,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.smoothLines,
              value,
            ),
          ),
          _PreferenceSwitch(
            label: 'Area fill',
            icon: Icons.gradient_rounded,
            value: chartPreferences.areaFill,
            onChanged: (value) =>
                chartPreferences.setPreference(ChartPreference.areaFill, value),
          ),
          _PreferenceSwitch(
            label: 'Grid',
            icon: Icons.grid_4x4_rounded,
            value: chartPreferences.gridLines,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.gridLines,
              value,
            ),
          ),
          _PreferenceSwitch(
            label: 'Motion',
            icon: Icons.animation_rounded,
            value: chartPreferences.animations,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.animations,
              value,
            ),
          ),
          Tooltip(
            message: 'Fetch telemetry and history now  •  Ctrl+R',
            child: OutlinedButton.icon(
              onPressed: telemetry.isRefreshing
                  ? null
                  : () => telemetry.refreshNow(includeHistory: true),
              icon: telemetry.isRefreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
                side: BorderSide(color: AppColors.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: value
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.overlay(context, 0.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: value ? AppColors.accent : AppColors.textMuted(context),
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
            const SizedBox(width: 4),
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> cards;
  final int preferredColumns;

  const _PerformanceSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.cards,
    this.preferredColumns = 2,
  });

  @override
  State<_PerformanceSection> createState() => _PerformanceSectionState();
}

class _PerformanceSectionState extends State<_PerformanceSection> {
  bool expanded = true;
  bool hovering = false;
  bool focused = false;

  void _toggle() => setState(() => expanded = !expanded);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused
              ? widget.accent.withValues(alpha: 0.6)
              : AppColors.border(context),
          width: focused ? 1.5 : 1,
        ),
        boxShadow: hovering
            ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.06),
                  blurRadius: 28,
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '${widget.title} section. ${expanded ? 'Collapse' : 'Expand'}.',
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
                    _toggle();
                    return null;
                  },
                ),
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => hovering = true),
                onExit: (_) => setState(() => hovering = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(
                              alpha: hovering || focused ? 0.16 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${widget.cards.length} metrics',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: expanded ? 0 : -0.25,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _ResponsiveMetricGrid(
                        preferredColumns: widget.preferredColumns,
                        cards: widget.cards,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  final List<Widget> cards;
  final int preferredColumns;

  const _ResponsiveMetricGrid({
    required this.cards,
    required this.preferredColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final responsiveColumns = availableWidth >= 1040
            ? 3
            : availableWidth >= 620
            ? 2
            : 1;
        final columns = responsiveColumns.clamp(1, preferredColumns);
        final aspectRatio = columns == 1
            ? 1.75
            : columns == 2
            ? 1.6
            : 1.4;

        return GridView.builder(
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}
