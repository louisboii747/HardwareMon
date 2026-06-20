import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/storage_models.dart';

Color storageHealthColor(StorageHealth health) {
  return switch (health) {
    StorageHealth.healthy => Colors.greenAccent,
    StorageHealth.warning => Colors.amberAccent,
    StorageHealth.critical => Colors.redAccent,
  };
}

String storageHealthLabel(StorageHealth health) {
  return switch (health) {
    StorageHealth.healthy => 'Healthy',
    StorageHealth.warning => 'Warning',
    StorageHealth.critical => 'Critical',
  };
}

String formatStorageBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final precision = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(precision)} ${units[unit]}';
}

String formatStorageRate(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 MB/s';
  return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(bytesPerSecond >= 100 * 1024 * 1024 ? 0 : 1)} MB/s';
}

class StorageHealthBadge extends StatelessWidget {
  final StorageHealth health;
  final String? label;

  const StorageHealthBadge({super.key, required this.health, this.label});

  @override
  Widget build(BuildContext context) {
    final color = storageHealthColor(health);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 14),
        ],
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
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label ?? storageHealthLabel(health),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StorageCapacityRing extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const StorageCapacityRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = 92,
    this.strokeWidth = 9,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: percent.clamp(0, 100)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _CapacityRingPainter(
              value: value / 100,
              color: color,
              trackColor: AppColors.overlay(context, 0.08),
              strokeWidth: strokeWidth,
            ),
            child:
                child ??
                Center(
                  child: Text(
                    '${value.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
          ),
        );
      },
      child: center,
    );
  }
}

class _CapacityRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _CapacityRingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = strokeWidth / 2 + 2;
    final arcRect = rect.deflate(inset);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.35), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _CapacityRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class StorageSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const StorageSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Collecting live samples…',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
          ),
        ),
      );
    }
    final maxValue = math.max(1.0, values.reduce(math.max) * 1.15);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, values.length - 1).toDouble(),
          minY: 0,
          maxY: maxValue,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < values.length; index++)
                  FlSpot(index.toDouble(), values[index]),
              ],
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class StorageActivityChart extends StatelessWidget {
  final List<StorageHistorySample> samples;
  final bool showRead;
  final bool showWrite;
  final bool showCombined;
  final double height;

  const StorageActivityChart({
    super.key,
    required this.samples,
    this.showRead = true,
    this.showWrite = true,
    this.showCombined = true,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                color: AppColors.textMuted(context),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                'Storage history will appear as telemetry accumulates.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final values = [
      for (final sample in samples) ...[
        if (showRead) sample.readBps,
        if (showWrite) sample.writeBps,
        if (showCombined) sample.readBps + sample.writeBps,
      ],
    ];
    final maxY = math
        .max(1024 * 1024, values.reduce(math.max) * 1.16)
        .toDouble();
    final start = samples.first.timestamp;
    final end = samples.last.timestamp;
    final span = math.max(1.0, end.difference(start).inMilliseconds.toDouble());
    List<FlSpot> spots(double Function(StorageHistorySample) read) {
      return [
        for (final sample in samples)
          FlSpot(
            sample.timestamp.difference(start).inMilliseconds / span,
            read(sample),
          ),
      ];
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.overlay(context, 0.045),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 4,
                getTitlesWidget: (value, _) => Text(
                  formatStorageRate(value),
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 0.25,
                getTitlesWidget: (value, _) {
                  final time = start.add(
                    Duration(milliseconds: (span * value.clamp(0, 1)).round()),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 8,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated(context),
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    formatStorageRate(spot.y),
                    TextStyle(
                      color: spot.barIndex == 0
                          ? Colors.cyanAccent
                          : Colors.purpleAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            if (showRead)
              _activityBar(
                spots((sample) => sample.readBps),
                Colors.cyanAccent,
              ),
            if (showWrite)
              _activityBar(
                spots((sample) => sample.writeBps),
                Colors.purpleAccent,
              ),
            if (showCombined)
              _activityBar(
                spots((sample) => sample.readBps + sample.writeBps),
                Colors.greenAccent,
                dashed: true,
              ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  LineChartBarData _activityBar(
    List<FlSpot> spots,
    Color color, {
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.2,
      dashArray: dashed ? const [7, 5] : null,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class StorageHeatmap extends StatelessWidget {
  final List<StorageHeatmapCell> cells;

  const StorageHeatmap({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final values = {
      for (final cell in cells)
        '${cell.weekday}-${cell.hour}': cell.throughputBps,
    };
    final maxValue = cells.isEmpty
        ? 1.0
        : math.max(
            1.0,
            cells.map((cell) => cell.throughputBps).reduce(math.max),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            for (final hour in [0, 6, 12, 18, 23])
              Expanded(
                child: Text(
                  hour.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var day = 0; day < 7; day++) ...[
          Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day],
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                  ),
                ),
              ),
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${hour.toString().padLeft(2, '0')}:00 · ${formatStorageRate(values['$day-$hour'] ?? 0)}',
                    child: Container(
                      height: 13,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          AppColors.overlay(context, 0.035),
                          Colors.cyanAccent,
                          ((values['$day-$hour'] ?? 0) / maxValue).clamp(0, 1),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class StorageFleetView extends StatelessWidget {
  final List<StorageDrive> drives;
  final ValueChanged<StorageDrive> onSelected;

  const StorageFleetView({
    super.key,
    required this.drives,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (drives.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'No mounted drives detected.',
            style: TextStyle(color: AppColors.textMuted(context)),
          ),
        ),
      );
    }
    final busiest = [...drives]
      ..sort(
        (a, b) => (b.readBps + b.writeBps).compareTo(a.readBps + a.writeBps),
      );
    final peakThroughput = math.max(
      1.0,
      busiest.map((drive) => drive.readBps + drive.writeBps).reduce(math.max),
    );
    return Column(
      children: [
        for (var index = 0; index < busiest.length; index++) ...[
          _StorageFleetTile(
            drive: busiest[index],
            peakThroughput: peakThroughput,
            onSelected: () => onSelected(busiest[index]),
          ),
          if (index != busiest.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _StorageFleetTile extends StatefulWidget {
  final StorageDrive drive;
  final double peakThroughput;
  final VoidCallback onSelected;

  const _StorageFleetTile({
    required this.drive,
    required this.peakThroughput,
    required this.onSelected,
  });

  @override
  State<_StorageFleetTile> createState() => _StorageFleetTileState();
}

class _StorageFleetTileState extends State<_StorageFleetTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final drive = widget.drive;
    final color = storageHealthColor(drive.health);
    final throughput = drive.readBps + drive.writeBps;
    final activity = (throughput / widget.peakThroughput).clamp(0.04, 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withValues(alpha: 0.07)
                : AppColors.overlay(context, 0.025),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _hovered
                  ? color.withValues(alpha: 0.3)
                  : AppColors.border(context),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 330;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          drive.removable
                              ? Icons.usb_rounded
                              : Icons.storage_rounded,
                          color: color,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drive.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${drive.mountPoint} · ${drive.usedPercent.toStringAsFixed(0)}% used',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatStorageRate(throughput),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted(context),
                        size: 17,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          color: AppColors.overlay(context, 0.055),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: activity),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.purpleAccent,
                                    color,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${formatStorageRate(drive.readBps)} read · ${formatStorageRate(drive.writeBps)} write',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
