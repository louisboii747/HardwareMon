import 'dart:async';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../utils/telemetry_chart.dart';
import '../utils/time_axis.dart';
import '../widgets/smooth_telemetry_series.dart';

class MetricFocusScreen extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<TelemetrySample> graphPoints;
  final ChartPreferences chartPreferences;
  final TelemetryMetricKind metricKind;

  const MetricFocusScreen({
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
  State<MetricFocusScreen> createState() => _MetricFocusScreenState();
}

class _MetricFocusScreenState extends State<MetricFocusScreen> {
  final FocusNode _chartFocusNode = FocusNode(debugLabel: 'Telemetry chart');

  late List<TelemetrySample> points;
  Timer? refreshTimer;
  int? selectedIndex;

  double get currentValue => points.isNotEmpty ? points.last.value : 0;

  TelemetrySample? get selectedSample {
    if (points.isEmpty || selectedIndex == null) return null;
    return points[selectedIndex!.clamp(0, points.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    points = _orderedCopy(widget.graphPoints);

    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final wasFollowingLatest =
          selectedIndex != null && selectedIndex == points.length - 1;
      setState(() {
        points = _orderedCopy(widget.graphPoints);
        if (points.isEmpty) {
          selectedIndex = null;
        } else if (wasFollowingLatest) {
          selectedIndex = points.length - 1;
        } else if (selectedIndex != null) {
          selectedIndex = selectedIndex!.clamp(0, points.length - 1);
        }
      });
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    _chartFocusNode.dispose();
    super.dispose();
  }

  List<TelemetrySample> _orderedCopy(List<TelemetrySample> source) {
    return source.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _moveSelection(int amount) {
    if (points.isEmpty) return;

    setState(() {
      selectedIndex = ((selectedIndex ?? points.length) + amount).clamp(
        0,
        points.length - 1,
      );
    });
    _chartFocusNode.requestFocus();
  }

  void _selectBoundary(bool first) {
    if (points.isEmpty) return;
    setState(() => selectedIndex = first ? 0 : points.length - 1);
    _chartFocusNode.requestFocus();
  }

  String _formatValue(double value) {
    return formatTelemetryValue(value, widget.metricKind);
  }

  Future<void> _toggleChartPreference(ChartPreference preference) async {
    await widget.chartPreferences.setPreference(
      preference,
      !widget.chartPreferences.valueFor(preference),
    );
    if (mounted) setState(() {});
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspectedSample = selectedSample;
    final average = points.isEmpty
        ? null
        : points.fold<double>(0, (sum, sample) => sum + sample.value) /
              points.length;
    final peak = points.isEmpty
        ? null
        : points.map((sample) => sample.value).reduce((a, b) => a > b ? a : b);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.home): () =>
            _selectBoundary(true),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _selectBoundary(false),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background(context),
          body: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: AppColors.overlay(context, 0.08)),
                ),
              ),
              Positioned(
                top: -120,
                right: -120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.95, end: 1),
                  duration: const Duration(seconds: 3),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.accent.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final horizontalPadding = viewport.maxWidth < 700
                        ? 24.0
                        : 40.0;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewport.maxHeight - horizontalPadding * 2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: 'Close  •  Esc',
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: viewport.maxHeight < 720 ? 28 : 56,
                            ),
                            Row(
                              children: [
                                Icon(
                                  widget.icon,
                                  color: widget.accent,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: currentValue),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return Text(
                                  _formatValue(value),
                                  style: TextStyle(
                                    fontSize: viewport.maxWidth < 700
                                        ? 76
                                        : 120,
                                    height: 0.9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -6,
                                    color: widget.accent,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 28,
                              runSpacing: 16,
                              children: [
                                _buildStat(
                                  'Average',
                                  average == null
                                      ? '--'
                                      : _formatValue(average),
                                ),
                                _buildStat(
                                  'Peak',
                                  peak == null ? '--' : _formatValue(peak),
                                ),
                                _buildStat('Samples', '${points.length}'),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _buildChart(inspectedSample),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(TelemetrySample? inspectedSample) {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.overlay(context, 0.05),
            AppColors.overlay(context, 0.02),
          ],
        ),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                inspectedSample == null
                    ? 'Timeline'
                    : _formatValue(inspectedSample.value),
                style: TextStyle(
                  color: inspectedSample == null
                      ? AppColors.textSecondary(context)
                      : widget.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    inspectedSample == null
                        ? 'Hover, click, or use ← → to inspect'
                        : formatTelemetryTooltipTimestamp(
                            inspectedSample.timestamp,
                          ),
                    key: ValueKey(inspectedSample?.timestamp),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChartToggleButton(
                label: 'Smooth',
                icon: Icons.gesture_rounded,
                active: widget.chartPreferences.smoothLines,
                accent: widget.accent,
                onPressed: () =>
                    _toggleChartPreference(ChartPreference.smoothLines),
              ),
              _ChartToggleButton(
                label: 'Fill',
                icon: Icons.gradient_rounded,
                active: widget.chartPreferences.areaFill,
                accent: widget.accent,
                onPressed: () =>
                    _toggleChartPreference(ChartPreference.areaFill),
              ),
              _ChartToggleButton(
                label: 'Grid',
                icon: Icons.grid_4x4_rounded,
                active: widget.chartPreferences.gridLines,
                accent: widget.accent,
                onPressed: () =>
                    _toggleChartPreference(ChartPreference.gridLines),
              ),
              _ChartToggleButton(
                label: 'Motion',
                icon: Icons.animation_rounded,
                active: widget.chartPreferences.animations,
                accent: widget.accent,
                onPressed: () =>
                    _toggleChartPreference(ChartPreference.animations),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.985 + (value * 0.015),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Focus(
                focusNode: _chartFocusNode,
                child: SmoothTelemetrySeries(
                  samples: points,
                  duration: widget.chartPreferences.animationDuration,
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
                        final spots = animatedSamples
                            .map(
                              (sample) => FlSpot(
                                scale.xFor(sample.timestamp),
                                sample.value,
                              ),
                            )
                            .toList(growable: false);

                        return LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: scale.maxX,
                            minY: 0,
                            maxY: chartMaxY,
                            gridData: FlGridData(
                              show: widget.chartPreferences.gridLines,
                              horizontalInterval: chartMaxY / 4,
                              verticalInterval: scale.tickInterval,
                              checkToShowVerticalLine: (value) =>
                                  scale.tickNear(value) != null,
                              getDrawingHorizontalLine: (_) {
                                return FlLine(
                                  color: AppColors.overlay(context, 0.035),
                                  strokeWidth: 1,
                                );
                              },
                              getDrawingVerticalLine: (_) {
                                return FlLine(
                                  color: AppColors.overlay(context, 0.055),
                                  strokeWidth: 1,
                                  dashArray: const [3, 5],
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: scale.tickInterval,
                                  minIncluded: true,
                                  maxIncluded: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    final tick = scale.tickNear(value);
                                    if (tick == null) {
                                      return const SizedBox.shrink();
                                    }

                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8,
                                      child: Text(
                                        tick.label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: AppColors.textMuted(
                                            context,
                                          ).withValues(alpha: 0.72),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.15,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              touchSpotThreshold: 18,
                              mouseCursorResolver: (_, _) =>
                                  SystemMouseCursors.precise,
                              touchCallback: (event, response) {
                                final touched = response?.lineBarSpots;
                                if (touched == null || touched.isEmpty) return;
                                final index = touched.first.spotIndex;
                                if (index == selectedIndex) return;

                                setState(() => selectedIndex = index);
                              },
                              getTouchedSpotIndicator: (barData, indexes) {
                                return indexes
                                    .map(
                                      (_) => TouchedSpotIndicatorData(
                                        FlLine(
                                          color: widget.accent.withValues(
                                            alpha: 0.45,
                                          ),
                                          strokeWidth: 1,
                                          dashArray: const [3, 4],
                                        ),
                                        FlDotData(
                                          getDotPainter:
                                              (spot, percent, barData, index) =>
                                                  FlDotCirclePainter(
                                                    radius: 4,
                                                    color: widget.accent,
                                                    strokeWidth: 3,
                                                    strokeColor:
                                                        AppColors.background(
                                                          context,
                                                        ),
                                                  ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false);
                              },
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBorderRadius: BorderRadius.circular(12),
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                tooltipMargin: 12,
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipColor: (_) =>
                                    AppColors.surfaceElevated(context),
                                tooltipBorder: BorderSide(
                                  color: widget.accent.withValues(alpha: 0.22),
                                ),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots
                                      .map((spot) {
                                        final sample = points[spot.spotIndex];
                                        return LineTooltipItem(
                                          '${_formatValue(sample.value)}\n'
                                          '${formatTelemetryTooltipTimestamp(sample.timestamp)}',
                                          TextStyle(
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            height: 1.45,
                                          ),
                                        );
                                      })
                                      .toList(growable: false);
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: widget.chartPreferences.smoothLines,
                                curveSmoothness: 0.45,
                                preventCurveOverShooting: true,
                                spots: spots,
                                showingIndicators: selectedIndex == null
                                    ? const []
                                    : [selectedIndex!],
                                color: widget.accent,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: widget.chartPreferences.areaFill,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      widget.accent.withValues(alpha: 0.25),
                                      widget.accent.withValues(alpha: 0.015),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onPressed;

  const _ChartToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${active ? 'Disable' : 'Enable'} ${label.toLowerCase()}',
      child: Semantics(
        button: true,
        toggled: active,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.13)
                  : AppColors.overlay(context, 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? accent.withValues(alpha: 0.32)
                    : AppColors.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active ? accent : AppColors.textMuted(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary(context)
                        : AppColors.textMuted(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
