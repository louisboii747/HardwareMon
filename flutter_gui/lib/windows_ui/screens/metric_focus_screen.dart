import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MetricFocusScreen extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<double> graphPoints;

  const MetricFocusScreen({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.graphPoints,
  });

  @override
  State<MetricFocusScreen> createState() => _MetricFocusScreenState();
}

class _MetricFocusScreenState extends State<MetricFocusScreen> {
  late List<double> points;
  late double currentValue;
  Timer? refreshTimer;
  late List<double> previousPoints;

  @override
  void initState() {
    super.initState();

    points = widget.graphPoints;
    previousPoints = List.from(points);

    currentValue = points.isNotEmpty ? points.last : 0;
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        points = List.from(widget.graphPoints);

        currentValue = points.isNotEmpty ? points.last : 0;
      });
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
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
    return Scaffold(
      backgroundColor: const Color(0xFF050505),

      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),

              child: Container(color: Colors.black.withOpacity(0.2)),
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
                      widget.accent.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),

                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Icon(widget.icon, color: widget.accent, size: 28),

                      const SizedBox(width: 12),

                      Text(
                        widget.title,

                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
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
                        "${value.round()}%",

                        style: TextStyle(
                          fontSize: 120,
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
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _buildStat(
                        "Average",
                        points.isNotEmpty
                            ? "${(points.reduce((a, b) => a + b) / points.length).round()}%"
                            : "--",
                      ),

                      const SizedBox(width: 28),

                      _buildStat(
                        "Peak",
                        points.isNotEmpty
                            ? "${points.reduce((a, b) => a > b ? a : b).round()}%"
                            : "--",
                      ),

                      const SizedBox(width: 28),

                      _buildStat("Samples", "${points.length}"),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Container(
                    height: 260,
                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),

                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,

                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),

                      border: Border.all(color: Colors.white.withOpacity(0.06)),

                      boxShadow: [
                        BoxShadow(
                          color: widget.accent.withOpacity(0.08),
                          blurRadius: 40,
                          spreadRadius: 1,
                        ),
                      ],
                    ),

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

                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: points.isEmpty
                              ? 30
                              : points.length.toDouble() - 1,
                          minY: 0,
                          maxY: 100,

                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,

                            getDrawingHorizontalLine: (_) {
                              return FlLine(
                                color: Colors.white.withOpacity(0.04),
                                strokeWidth: 1,
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
                                reservedSize: 24,

                                getTitlesWidget: (value, meta) {
                                  final max = points.length - 1;

                                  if (max <= 0) {
                                    return const SizedBox();
                                  }

                                  final interval = (max / 4).round();

                                  if (interval == 0) {
                                    return const SizedBox();
                                  }

                                  if (value.toInt() % interval != 0) {
                                    return const SizedBox();
                                  }

                                  final minutes = (value.toInt() * 5) ~/ 60;

                                  return Text(
                                    "${minutes}m",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          borderData: FlBorderData(show: false),

                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              curveSmoothness: 0.55,
                              preventCurveOverShooting: true,

                              spots: List.generate(
                                points.length,
                                (i) => FlSpot(i.toDouble(), points[i]),
                              ),

                              color: widget.accent,
                              barWidth: 4,
                              isStrokeCapRound: true,

                              dotData: const FlDotData(show: false),

                              belowBarData: BarAreaData(
                                show: true,

                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,

                                  colors: [
                                    widget.accent.withOpacity(0.28),
                                    widget.accent.withOpacity(0.02),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
