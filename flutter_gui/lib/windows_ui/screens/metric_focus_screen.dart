import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MetricFocusScreen extends StatefulWidget {
  final String title;
  final String value;
  final Color accent;

  const MetricFocusScreen({
    super.key,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  State<MetricFocusScreen> createState() => _MetricFocusScreenState();
}

class _MetricFocusScreenState extends State<MetricFocusScreen> {
  final List<double> points = [24, 32, 28, 46, 40, 58, 52, 67, 62, 72, 66, 78];
  late double currentValue;

  @override
  void initState() {
    super.initState();
    currentValue = points.last;

    _startFakeTelemetry();
  }

  void _startFakeTelemetry() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return false;

      setState(() {
        points.removeAt(0);

        final next =
            (40 +
                    (points.last * 0.6) +
                    (15 - (DateTime.now().millisecond % 30)))
                .clamp(18, 95);

        points.add(next.toDouble());
        currentValue = next.toDouble();
      });

      return true;
    });
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

            child: Container(
              width: 320,
              height: 320,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: RadialGradient(
                  colors: [widget.accent.withOpacity(0.12), Colors.transparent],
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

                  Text(
                    widget.title,

                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: currentValue, end: currentValue),

                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,

                    builder: (context, value, _) {
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        scale: 1.0,

                        child: Text(
                          "${value.round()}%",

                          style: TextStyle(
                            fontSize: 120,
                            height: 0.9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -6,
                            color: widget.accent,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

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

                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 11,
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

                        titlesData: const FlTitlesData(show: false),

                        borderData: FlBorderData(show: false),

                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: 0.35,

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
