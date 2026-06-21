import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/theme/app_colors.dart';
import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../models/telemetry_statistics.dart';
import '../screens/metric_focus_screen.dart';
import '../utils/telemetry_chart.dart';
import '../utils/time_axis.dart';
import 'glass_panel.dart';
import 'metric_alert_action.dart';
import 'smooth_telemetry_series.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<TelemetrySample> graphPoints;
  final ChartPreferences chartPreferences;
  final TelemetryMetricKind metricKind;
  final DateTime? statisticsSince;
  final MetricAlertKind? alertKind;
  final double? alertValue;
  final bool hoverEffects;
  final Duration transitionDuration;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.graphPoints,
    required this.chartPreferences,
    this.metricKind = TelemetryMetricKind.percentage,
    this.statisticsSince,
    this.alertKind,
    this.alertValue,
    this.hoverEffects = true,
    this.transitionDuration = const Duration(milliseconds: 220),
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool hovering = false;
  bool focused = false;

  void _openMetric() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        opaque: false,
        pageBuilder: (_, _, _) {
          return MetricFocusScreen(
            title: widget.title,
            value: widget.value,
            subtitle: widget.subtitle,
            accent: widget.accent,
            icon: widget.icon,
            graphPoints: widget.graphPoints,
            chartPreferences: widget.chartPreferences,
            metricKind: widget.metricKind,
            statisticsSince: widget.statisticsSince,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return Transform.scale(
                scale: 0.98 + (animation.value * 0.02),
                child: Opacity(opacity: animation.value, child: child),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _copyValue() async {
    await Clipboard.setData(
      ClipboardData(text: '${widget.title}: ${widget.value}'),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _configureAlert() async {
    final alertKind = widget.alertKind;
    final alertValue = widget.alertValue;
    if (alertKind == null || alertValue == null) return;

    final applied = await showMetricAlertDialog(
      context: context,
      kind: alertKind,
      currentValue: alertValue,
    );
    if (!mounted || !applied) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} watch applied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showContextMenu(TapDownDetails details) async {
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open details')),
        const PopupMenuItem(value: 'copy', child: Text('Copy current value')),
        if (widget.alertKind != null)
          const PopupMenuItem(
            value: 'alert',
            child: Text('Create or edit watch'),
          ),
      ],
    );

    if (selection == 'open') _openMetric();
    if (selection == 'copy') await _copyValue();
    if (selection == 'alert') await _configureAlert();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = AppColors.textSecondary(context);
    final subtitleColor = AppColors.textMuted(context);
    final statistics = calculateTelemetryStatistics(
      widget.graphPoints,
      since: widget.statisticsSince,
    );

    return AnimatedBuilder(
      animation: widget.chartPreferences,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.hasBoundedHeight && constraints.maxHeight < 270;
          final panelPadding = compact ? 16.0 : 24.0;
          final headerSize = compact ? 36.0 : 42.0;
          final chartHeight = compact ? 28.0 : 36.0;
          final sectionGap = compact ? 6.0 : 10.0;
          final hoverEffectsActive =
              widget.hoverEffects && (hovering || focused);
          final valueSize = compact
              ? (hoverEffectsActive ? 32.0 : 28.0)
              : (hoverEffectsActive ? 38.0 : 32.0);

          return Semantics(
            button: true,
            label: '${widget.title}, ${widget.value}. Open detailed chart.',
            child: Tooltip(
              message: 'Open ${widget.title} details  •  Enter',
              waitDuration: const Duration(milliseconds: 550),
              child: FocusableActionDetector(
                mouseCursor: SystemMouseCursors.click,
                onShowFocusHighlight: (value) =>
                    setState(() => focused = value),
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                },
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _openMetric();
                      return null;
                    },
                  ),
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => hovering = true),
                  onExit: (_) => setState(() => hovering = false),
                  child: GestureDetector(
                    onTap: _openMetric,
                    onSecondaryTapDown: _showContextMenu,
                    child: AnimatedScale(
                      duration: widget.transitionDuration,
                      curve: Curves.easeOutCubic,
                      scale: hoverEffectsActive ? 1.01 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: focused
                                ? widget.accent.withValues(alpha: 0.75)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Hero(
                          tag: widget.title,
                          child: GlassPanel(
                            padding: EdgeInsets.all(panelPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: headerSize,
                                      height: headerSize,

                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: widget.accent.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),

                                      child: Icon(
                                        widget.icon,
                                        color: widget.accent,
                                        size: 20,
                                      ),
                                    ),

                                    const Spacer(),

                                    if (statistics.sampleCount > 1) ...[
                                      _TrendBadge(
                                        statistics: statistics,
                                        metricKind: widget.metricKind,
                                      ),
                                      const SizedBox(width: 6),
                                    ],

                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      child: hoverEffectsActive
                                          ? Row(
                                              key: const ValueKey('actions'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (widget.alertKind != null)
                                                  Tooltip(
                                                    message:
                                                        'Create or edit a metric watch',
                                                    child: IconButton(
                                                      onPressed:
                                                          _configureAlert,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      iconSize: 15,
                                                      icon: const Icon(
                                                        Icons
                                                            .notifications_none_rounded,
                                                      ),
                                                    ),
                                                  ),
                                                Tooltip(
                                                  message: 'Copy current value',
                                                  child: IconButton(
                                                    onPressed: _copyValue,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    iconSize: 15,
                                                    icon: const Icon(
                                                      Icons.copy_rounded,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(
                                              key: ValueKey('hidden'),
                                            ),
                                    ),

                                    const SizedBox(width: 4),

                                    Container(
                                      width: 8,
                                      height: 8,

                                      decoration: BoxDecoration(
                                        color: widget.accent,
                                        shape: BoxShape.circle,

                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.accent.withValues(
                                              alpha: 0.45,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: sectionGap),

                                SizedBox(
                                  height: chartHeight,
                                  child: SmoothTelemetrySeries(
                                    samples: widget.graphPoints,
                                    duration: widget
                                        .chartPreferences
                                        .animationDuration,
                                    builder: (context, animatedSamples) {
                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final scale = generateTimeAxisTicks(
                                            samples: animatedSamples,
                                            width: constraints.maxWidth,
                                            density: widget
                                                .chartPreferences
                                                .timelineDensity,
                                          );
                                          final chartMaxY = telemetryChartMaxY(
                                            animatedSamples,
                                            widget.metricKind,
                                          );

                                          return LineChart(
                                            LineChartData(
                                              minX: 0,
                                              maxX: scale.maxX,
                                              minY: 0,
                                              maxY: chartMaxY,
                                              gridData: FlGridData(
                                                show: widget
                                                    .chartPreferences
                                                    .gridLines,
                                                drawHorizontalLine: true,
                                                horizontalInterval:
                                                    chartMaxY / 2,
                                                drawVerticalLine: true,
                                                verticalInterval:
                                                    scale.tickInterval,
                                                getDrawingHorizontalLine: (_) =>
                                                    FlLine(
                                                      color: AppColors.overlay(
                                                        context,
                                                        0.025,
                                                      ),
                                                      strokeWidth: 1,
                                                    ),
                                                getDrawingVerticalLine: (_) =>
                                                    FlLine(
                                                      color: AppColors.overlay(
                                                        context,
                                                        0.03,
                                                      ),
                                                      strokeWidth: 1,
                                                    ),
                                              ),
                                              titlesData: const FlTitlesData(
                                                show: false,
                                              ),
                                              borderData: FlBorderData(
                                                show: false,
                                              ),
                                              lineTouchData:
                                                  const LineTouchData(
                                                    enabled: false,
                                                  ),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  isCurved: widget
                                                      .chartPreferences
                                                      .smoothLines,
                                                  curveSmoothness: widget
                                                      .chartPreferences
                                                      .smoothness,
                                                  preventCurveOverShooting:
                                                      true,
                                                  spots: animatedSamples
                                                      .map(
                                                        (sample) => FlSpot(
                                                          scale.xFor(
                                                            sample.timestamp,
                                                          ),
                                                          sample.value,
                                                        ),
                                                      )
                                                      .toList(growable: false),
                                                  color: widget.accent,
                                                  barWidth: widget
                                                      .chartPreferences
                                                      .thickness,
                                                  isStrokeCapRound: true,
                                                  dotData: const FlDotData(
                                                    show: false,
                                                  ),
                                                  belowBarData: BarAreaData(
                                                    show: widget
                                                        .chartPreferences
                                                        .areaFill,
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        widget.accent
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        widget.accent
                                                            .withValues(
                                                              alpha: 0,
                                                            ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            duration: Duration.zero,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                                SizedBox(height: sectionGap),

                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: compact ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                SizedBox(height: compact ? 2 : 4),

                                Text(
                                  widget.value,
                                  style: TextStyle(
                                    fontSize: valueSize,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -2,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),

                                SizedBox(height: compact ? 2 : 4),

                                Text(
                                  widget.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: compact ? 11 : 12,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final TelemetryStatistics statistics;
  final TelemetryMetricKind metricKind;

  const _TrendBadge({required this.statistics, required this.metricKind});

  @override
  Widget build(BuildContext context) {
    final rising = statistics.isRising;
    final falling = statistics.isFalling;
    final color = rising
        ? Colors.orangeAccent
        : falling
        ? Colors.lightBlueAccent
        : AppColors.textMuted(context);
    final icon = rising
        ? Icons.trending_up_rounded
        : falling
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final delta = statistics.delta.abs();

    return Tooltip(
      message:
          'Since the previous sample: ${rising
              ? '+'
              : falling
              ? '−'
              : ''}${formatTelemetryValue(delta, metricKind)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
