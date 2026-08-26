import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../models/telemetry_statistics.dart';
import '../screens/metric_focus_screen.dart';
import '../utils/telemetry_chart.dart';
import '../utils/time_axis.dart';
import 'metric_alert_action.dart';
import 'rolling_metric_text.dart';
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
    this.transitionDuration = const Duration(milliseconds: 180),
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
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        opaque: false,
        pageBuilder: (_, _, _) => MetricFocusScreen(
          title: widget.title,
          value: widget.value,
          subtitle: widget.subtitle,
          accent: widget.accent,
          icon: widget.icon,
          graphPoints: widget.graphPoints,
          chartPreferences: widget.chartPreferences,
          metricKind: widget.metricKind,
          statisticsSince: widget.statisticsSince,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.018, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
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
    final kind = widget.alertKind;
    final value = widget.alertValue;
    if (kind == null || value == null) return;

    final applied = await showMetricAlertDialog(
      context: context,
      kind: kind,
      currentValue: value,
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
    final statistics = calculateTelemetryStatistics(
      widget.graphPoints,
      since: widget.statisticsSince,
    );
    final active = widget.hoverEffects && (hovering || focused);

    return AnimatedBuilder(
      animation: widget.chartPreferences,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.hasBoundedHeight && constraints.maxHeight < 260;
          return Semantics(
            button: true,
            label: '${widget.title}, ${widget.value}. Open detailed chart.',
            child: Tooltip(
              message: 'Open ${widget.title} details  •  Enter',
              waitDuration: const Duration(milliseconds: 520),
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
                    child: Hero(
                      tag: widget.title,
                      child: AnimatedContainer(
                        duration: widget.transitionDuration,
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(compact ? 14 : 18),
                        decoration: BoxDecoration(
                          color: active
                              ? Color.alphaBlend(
                                  widget.accent.withValues(alpha: 0.045),
                                  AppColors.surface(context),
                                )
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: focused
                                ? widget.accent
                                : AppColors.rule(context),
                            width: focused ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(
                              title: widget.title,
                              icon: widget.icon,
                              accent: widget.accent,
                              statistics: statistics,
                              metricKind: widget.metricKind,
                              actionsVisible: active,
                              hasAlert: widget.alertKind != null,
                              onAlert: _configureAlert,
                              onCopy: _copyValue,
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: compact ? 112 : 132,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        RollingMetricText(
                                          value: widget.value,
                                          style: AppTypography.metric.copyWith(
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                            fontSize: compact ? 27 : 34,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.subtitle,
                                          maxLines: compact ? 1 : 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.metadata
                                              .copyWith(
                                                color: AppColors.textMuted(
                                                  context,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    color: AppColors.rule(context),
                                  ),
                                  Expanded(
                                    child: _MetricPlot(
                                      samples: widget.graphPoints,
                                      preferences: widget.chartPreferences,
                                      kind: widget.metricKind,
                                      accent: widget.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!compact && statistics.sampleCount > 1) ...[
                              const SizedBox(height: 10),
                              Divider(color: AppColors.rule(context)),
                              const SizedBox(height: 8),
                              _StatisticsLine(
                                statistics: statistics,
                                kind: widget.metricKind,
                              ),
                            ],
                          ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.icon,
    required this.accent,
    required this.statistics,
    required this.metricKind,
    required this.actionsVisible,
    required this.hasAlert,
    required this.onAlert,
    required this.onCopy,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final TelemetryStatistics statistics;
  final TelemetryMetricKind metricKind;
  final bool actionsVisible;
  final bool hasAlert;
  final VoidCallback onAlert;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: accent),
        const SizedBox(width: 9),
        Icon(icon, size: 18, color: AppColors.textSecondary(context)),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.heading.copyWith(
            color: AppColors.textPrimary(context),
            fontSize: 18,
          ),
        ),
        const Spacer(),
        if (statistics.sampleCount > 1)
          _TrendBadge(statistics: statistics, metricKind: metricKind),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: actionsVisible
              ? Row(
                  key: const ValueKey('metric-actions'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAlert)
                      _SmallAction(
                        tooltip: 'Create or edit a metric watch',
                        icon: Icons.notifications_none_rounded,
                        onPressed: onAlert,
                      ),
                    _SmallAction(
                      tooltip: 'Copy current value',
                      icon: Icons.copy_rounded,
                      onPressed: onCopy,
                    ),
                  ],
                )
              : Text(
                  'LIVE',
                  key: const ValueKey('metric-live'),
                  style: AppTypography.sectionLabel.copyWith(color: accent),
                ),
        ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        iconSize: 15,
        icon: Icon(icon),
      ),
    );
  }
}

class _MetricPlot extends StatelessWidget {
  const _MetricPlot({
    required this.samples,
    required this.preferences,
    required this.kind,
    required this.accent,
  });

  final List<TelemetrySample> samples;
  final ChartPreferences preferences;
  final TelemetryMetricKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SmoothTelemetrySeries(
      samples: samples,
      duration: preferences.animationDuration,
      builder: (context, animatedSamples) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final scale = generateTimeAxisTicks(
              samples: animatedSamples,
              width: constraints.maxWidth,
              density: preferences.timelineDensity,
            );
            final maxY = telemetryChartMaxY(animatedSamples, kind);
            final spots = animatedSamples.isEmpty
                ? const <FlSpot>[]
                : animatedSamples
                      .asMap()
                      .entries
                      .map(
                        (entry) =>
                            FlSpot(entry.key.toDouble(), entry.value.value),
                      )
                      .toList(growable: false);

            return LineChart(
              LineChartData(
                minX: 0,
                maxX: scale.maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: preferences.gridLines,
                  drawHorizontalLine: true,
                  horizontalInterval: maxY / 2,
                  drawVerticalLine: true,
                  verticalInterval: scale.tickInterval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.rule(context).withValues(alpha: 0.55),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: AppColors.rule(context).withValues(alpha: 0.38),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: preferences.smoothLines,
                    curveSmoothness: 0.2,
                    color: accent,
                    barWidth: 1.7,
                    isStrokeCapRound: false,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: preferences.areaFill,
                      color: accent.withValues(alpha: 0.055),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            );
          },
        );
      },
    );
  }
}

class _StatisticsLine extends StatelessWidget {
  const _StatisticsLine({required this.statistics, required this.kind});

  final TelemetryStatistics statistics;
  final TelemetryMetricKind kind;

  @override
  Widget build(BuildContext context) {
    TextSpan stat(String label, double value) {
      return TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: formatTelemetryValue(value, kind),
            style: AppTypography.metric.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        style: AppTypography.metadata.copyWith(
          color: AppColors.textMuted(context),
        ),
        children: [
          stat('MIN', statistics.minimum),
          const TextSpan(text: '     '),
          stat('AVG', statistics.average),
          const TextSpan(text: '     '),
          stat('MAX', statistics.maximum),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.statistics, required this.metricKind});

  final TelemetryStatistics statistics;
  final TelemetryMetricKind metricKind;

  @override
  Widget build(BuildContext context) {
    final rising = statistics.isRising;
    final falling = statistics.isFalling;
    final color = rising
        ? const Color(0xFF9A7338)
        : falling
        ? AppColors.accent
        : AppColors.textMuted(context);
    final icon = rising
        ? Icons.north_east_rounded
        : falling
        ? Icons.south_east_rounded
        : Icons.east_rounded;
    final delta = statistics.delta.abs();

    return Tooltip(
      message:
          'Since the previous sample: ${rising
              ? '+'
              : falling
              ? '−'
              : ''}${formatTelemetryValue(delta, metricKind)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.rule(context)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              formatTelemetryValue(delta, metricKind),
              style: AppTypography.metric.copyWith(color: color, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
