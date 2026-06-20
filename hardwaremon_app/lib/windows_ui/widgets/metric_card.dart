import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/theme/app_colors.dart';
import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../screens/metric_focus_screen.dart';
import '../utils/telemetry_chart.dart';
import '../utils/time_axis.dart';
import 'glass_panel.dart';
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

  @override
  Widget build(BuildContext context) {
    final titleColor = AppColors.textSecondary(context);
    final subtitleColor = AppColors.textMuted(context);

    return AnimatedBuilder(
      animation: widget.chartPreferences,
      builder: (context, _) => Semantics(
        button: true,
        label: '${widget.title}, ${widget.value}. Open detailed chart.',
        child: Tooltip(
          message: 'Open ${widget.title} details  •  Enter',
          waitDuration: const Duration(milliseconds: 550),
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
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: hovering || focused ? 1.01 : 1,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,

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

                            const SizedBox(height: 10),

                            SizedBox(
                              height: 36,
                              child: SmoothTelemetrySeries(
                                samples: widget.graphPoints,
                                duration:
                                    widget.chartPreferences.animationDuration,
                                builder: (context, animatedSamples) {
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final scale = generateTimeAxisTicks(
                                        samples: animatedSamples,
                                        width: constraints.maxWidth,
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
                                            horizontalInterval: chartMaxY / 2,
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
                                          borderData: FlBorderData(show: false),
                                          lineTouchData: const LineTouchData(
                                            enabled: false,
                                          ),
                                          lineBarsData: [
                                            LineChartBarData(
                                              isCurved: widget
                                                  .chartPreferences
                                                  .smoothLines,
                                              curveSmoothness: 0.38,
                                              preventCurveOverShooting: true,
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
                                              barWidth: 2,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(
                                                show: false,
                                              ),
                                              belowBarData: BarAreaData(
                                                show: widget
                                                    .chartPreferences
                                                    .areaFill,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    widget.accent.withValues(
                                                      alpha: 0.18,
                                                    ),
                                                    widget.accent.withValues(
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

                            const SizedBox(height: 10),

                            Text(
                              widget.title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              widget.value,
                              style: TextStyle(
                                fontSize: hovering || focused ? 38 : 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -2,
                                color: AppColors.textPrimary(context),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
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
      ),
    );
  }
}
