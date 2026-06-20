import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../models/telemetry_statistics.dart';
import '../services/telemetry_service.dart';
import '../utils/time_axis.dart';
import 'smooth_telemetry_series.dart';

enum _StudioMetric { cpu, memory, gpu }

class TelemetryStudioPage extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;

  const TelemetryStudioPage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.pageGradient(context),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TelemetryStudio(
              telemetry: telemetry,
              chartPreferences: chartPreferences,
              expanded: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioSeries {
  final _StudioMetric metric;
  final String label;
  final Color color;
  final List<TelemetrySample> samples;

  const _StudioSeries({
    required this.metric,
    required this.label,
    required this.color,
    required this.samples,
  });
}

class TelemetryStudio extends StatefulWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;
  final bool expanded;

  const TelemetryStudio({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
    this.expanded = false,
  });

  @override
  State<TelemetryStudio> createState() => _TelemetryStudioState();
}

class _TelemetryStudioState extends State<TelemetryStudio> {
  final Set<_StudioMetric> _visibleMetrics = {
    _StudioMetric.cpu,
    _StudioMetric.memory,
    _StudioMetric.gpu,
  };

  void _toggleMetric(_StudioMetric metric) {
    setState(() {
      if (_visibleMetrics.contains(metric)) {
        if (_visibleMetrics.length > 1) {
          _visibleMetrics.remove(metric);
        }
      } else {
        _visibleMetrics.add(metric);
      }
    });
  }

  Future<void> _openExpanded() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TelemetryStudioPage(
          telemetry: widget.telemetry,
          chartPreferences: widget.chartPreferences,
        ),
      ),
    );
  }

  List<TelemetrySample> _combinedSamples(
    List<TelemetrySample> historical,
    List<TelemetrySample> live,
  ) {
    final cutoff = DateTime.now().subtract(
      widget.telemetry.historicalRange.duration,
    );
    final byTimestamp = <int, TelemetrySample>{};

    for (final sample in [...historical, ...live]) {
      if (!sample.timestamp.isBefore(cutoff)) {
        byTimestamp[sample.timestamp.millisecondsSinceEpoch] = sample;
      }
    }

    final samples = byTimestamp.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return samples;
  }

  List<_StudioSeries> _series() {
    return [
      _StudioSeries(
        metric: _StudioMetric.cpu,
        label: 'CPU',
        color: Colors.cyan,
        samples: _combinedSamples(
          widget.telemetry.historicalCpuHistory,
          widget.telemetry.cpuHistory,
        ),
      ),
      _StudioSeries(
        metric: _StudioMetric.memory,
        label: 'Memory',
        color: Colors.purpleAccent,
        samples: _combinedSamples(
          widget.telemetry.historicalRamHistory,
          widget.telemetry.ramHistory,
        ),
      ),
      _StudioSeries(
        metric: _StudioMetric.gpu,
        label: 'GPU',
        color: Colors.orangeAccent,
        samples: _combinedSamples(
          widget.telemetry.historicalGpuHistory,
          widget.telemetry.gpuUsageHistory,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.telemetry, widget.chartPreferences]),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final series = _series();
    final chartHeight = widget.expanded ? 520.0 : 330.0;

    return Container(
      margin: widget.expanded
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(widget.expanded ? 24 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.expanded ? 28 : 22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated(context),
            AppColors.surface(context),
          ],
        ),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
            blurRadius: 42,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildMetricSummaries(series),
          const SizedBox(height: 18),
          SizedBox(height: chartHeight, child: _buildAnimatedChart(series)),
          const SizedBox(height: 12),
          _buildFooter(context, series),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: widget.expanded ? 360 : 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Telemetry Studio',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Compare CPU, memory, and GPU activity on one synchronized timeline.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        ...TelemetryTimeRange.values.map(
          (range) => ChoiceChip(
            label: Text(_shortRangeLabel(range)),
            selected: widget.telemetry.historicalRange == range,
            onSelected: (_) => widget.telemetry.setHistoricalRange(range),
            selectedColor: AppColors.accent.withValues(alpha: 0.2),
            side: BorderSide(
              color: widget.telemetry.historicalRange == range
                  ? AppColors.accent.withValues(alpha: 0.35)
                  : AppColors.border(context),
            ),
            labelStyle: TextStyle(
              color: widget.telemetry.historicalRange == range
                  ? AppColors.textPrimary(context)
                  : AppColors.textMuted(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Tooltip(
          message: widget.expanded ? 'Close expanded view' : 'Expand studio',
          child: IconButton(
            onPressed: widget.expanded
                ? () => Navigator.maybePop(context)
                : _openExpanded,
            icon: Icon(
              widget.expanded
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricSummaries(List<_StudioSeries> series) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 840
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 520
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: series
              .map((item) {
                final statistics = calculateTelemetryStatistics(item.samples);
                final active = _visibleMetrics.contains(item.metric);

                return SizedBox(
                  width: tileWidth,
                  child: _StudioMetricTile(
                    label: item.label,
                    color: item.color,
                    statistics: statistics,
                    active: active,
                    onTap: () => _toggleMetric(item.metric),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildAnimatedChart(List<_StudioSeries> series) {
    return SmoothTelemetrySeries(
      samples: series[0].samples,
      duration: widget.chartPreferences.animationDuration,
      builder: (context, cpuSamples) {
        return SmoothTelemetrySeries(
          samples: series[1].samples,
          duration: widget.chartPreferences.animationDuration,
          builder: (context, memorySamples) {
            return SmoothTelemetrySeries(
              samples: series[2].samples,
              duration: widget.chartPreferences.animationDuration,
              builder: (context, gpuSamples) {
                final animatedSeries = [
                  _StudioSeries(
                    metric: _StudioMetric.cpu,
                    label: 'CPU',
                    color: Colors.cyan,
                    samples: cpuSamples,
                  ),
                  _StudioSeries(
                    metric: _StudioMetric.memory,
                    label: 'Memory',
                    color: Colors.purpleAccent,
                    samples: memorySamples,
                  ),
                  _StudioSeries(
                    metric: _StudioMetric.gpu,
                    label: 'GPU',
                    color: Colors.orangeAccent,
                    samples: gpuSamples,
                  ),
                ];
                return _buildChart(animatedSeries);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChart(List<_StudioSeries> series) {
    final activeSeries = series
        .where((item) => _visibleMetrics.contains(item.metric))
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisSamples = activeSeries
            .expand((item) => item.samples)
            .toList(growable: false);
        final scale = generateTimeAxisTicks(
          samples: axisSamples,
          width: constraints.maxWidth,
        );

        if (axisSamples.isEmpty) {
          return Center(
            child: widget.telemetry.isHistoryLoading
                ? const CircularProgressIndicator()
                : Text(
                    'No samples are available for this range yet.',
                    style: TextStyle(color: AppColors.textMuted(context)),
                  ),
          );
        }

        return Stack(
          children: [
            LineChart(
              LineChartData(
                minX: 0,
                maxX: scale.maxX,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: widget.chartPreferences.gridLines,
                  horizontalInterval: 25,
                  verticalInterval: scale.tickInterval,
                  checkToShowVerticalLine: (value) =>
                      scale.tickNear(value) != null,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.overlay(context, 0.04),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: AppColors.overlay(context, 0.055),
                    strokeWidth: 1,
                    dashArray: const [3, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: widget.expanded,
                      reservedSize: 34,
                      interval: 25,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${value.round()}%',
                          style: TextStyle(
                            color: AppColors.textMuted(
                              context,
                            ).withValues(alpha: 0.65),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
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
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final tick = scale.tickNear(value);
                        if (tick == null) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            tick.label,
                            style: TextStyle(
                              color: AppColors.textMuted(
                                context,
                              ).withValues(alpha: 0.72),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBorderRadius: BorderRadius.circular(12),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => AppColors.surfaceElevated(context),
                    tooltipBorder: BorderSide(color: AppColors.border(context)),
                    getTooltipItems: (spots) => spots
                        .map((spot) {
                          final item = activeSeries[spot.barIndex];
                          final sample = item.samples[spot.spotIndex];
                          return LineTooltipItem(
                            '${item.label}  ${sample.value.toStringAsFixed(1)}%\n'
                            '${formatTelemetryTooltipTimestamp(sample.timestamp)}',
                            TextStyle(
                              color: item.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                  getTouchedSpotIndicator: (barData, indexes) => indexes
                      .map(
                        (_) => TouchedSpotIndicatorData(
                          FlLine(
                            color: (barData.color ?? Colors.white).withValues(
                              alpha: 0.45,
                            ),
                            strokeWidth: 1,
                          ),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: barData.color ?? Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: AppColors.background(context),
                                ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                lineBarsData: activeSeries
                    .map((item) {
                      return LineChartBarData(
                        spots: item.samples
                            .map(
                              (sample) => FlSpot(
                                scale.xFor(sample.timestamp),
                                sample.value,
                              ),
                            )
                            .toList(growable: false),
                        isCurved: widget.chartPreferences.smoothLines,
                        curveSmoothness: 0.38,
                        preventCurveOverShooting: true,
                        color: item.color,
                        barWidth: widget.expanded ? 3.2 : 2.6,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show:
                              widget.chartPreferences.areaFill &&
                              activeSeries.length == 1,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              item.color.withValues(alpha: 0.24),
                              item.color.withValues(alpha: 0.01),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              duration: Duration.zero,
            ),
            if (widget.telemetry.isHistoryLoading)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.7),
                      ),
                      SizedBox(width: 7),
                      Text('Loading range', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, List<_StudioSeries> series) {
    final sampleCount = series
        .where((item) => _visibleMetrics.contains(item.metric))
        .fold<int>(0, (total, item) => total + item.samples.length);

    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: AppColors.textMuted(context),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$sampleCount plotted samples · database ranges are automatically downsampled for responsiveness',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
        ),
        TextButton.icon(
          onPressed: () => widget.telemetry.loadHistory(
            range: widget.telemetry.historicalRange,
          ),
          icon: const Icon(Icons.sync_rounded, size: 14),
          label: const Text('Sync'),
        ),
      ],
    );
  }

  String _shortRangeLabel(TelemetryTimeRange range) {
    return switch (range) {
      TelemetryTimeRange.last5Minutes => '5m',
      TelemetryTimeRange.last30Minutes => '30m',
      TelemetryTimeRange.last1Hour => '1h',
      TelemetryTimeRange.last24Hours => '24h',
      TelemetryTimeRange.last7Days => '7d',
      TelemetryTimeRange.last30Days => '30d',
    };
  }
}

class _StudioMetricTile extends StatelessWidget {
  final String label;
  final Color color;
  final TelemetryStatistics statistics;
  final bool active;
  final VoidCallback onTap;

  const _StudioMetricTile({
    required this.label,
    required this.color,
    required this.statistics,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = statistics.current >= 90
        ? 'Critical'
        : statistics.current >= 75
        ? 'High'
        : 'Normal';
    final statusColor = statistics.current >= 90
        ? Colors.redAccent
        : statistics.current >= 75
        ? Colors.amber
        : Colors.greenAccent;

    return Semantics(
      button: true,
      selected: active,
      label: '$label chart series',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: active ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.075)
                  : AppColors.overlay(context, 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.24)
                    : AppColors.border(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  statistics.sampleCount == 0
                      ? '--'
                      : '${statistics.current.round()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _MiniStat(label: 'MIN', value: statistics.minimum),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'AVG', value: statistics.average),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'MAX', value: statistics.maximum),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: '${value.round()}%'),
        ],
      ),
    );
  }
}
