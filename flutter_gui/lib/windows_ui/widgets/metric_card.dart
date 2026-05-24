import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../screens/metric_focus_screen.dart';
import 'glass_panel.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<double> graphPoints;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.graphPoints,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),

      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,

            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 700),
              reverseTransitionDuration: const Duration(milliseconds: 500),

              opaque: false,

              pageBuilder: (_, __, ___) {
                return MetricFocusScreen(
                  title: widget.title,
                  value: widget.value,
                  subtitle: widget.subtitle,
                  accent: widget.accent,
                  icon: widget.icon,
                  graphPoints: widget.graphPoints,
                );
              },

              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return AnimatedBuilder(
                      animation: animation,

                      builder: (context, _) {
                        return Transform.scale(
                          scale: 0.98 + (animation.value * 0.02),

                          child: Opacity(
                            opacity: animation.value,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
            ),
          );
        },

        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: hovering ? 1.01 : 1,

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
                          color: widget.accent.withOpacity(0.12),
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
                              color: widget.accent.withOpacity(0.45),
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

                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: widget.graphPoints.isEmpty
                            ? 30
                            : widget.graphPoints.length.toDouble() - 1,
                        minY: 0,
                        maxY: 100,

                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),

                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,

                            spots: List.generate(
                              widget.graphPoints.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                widget.graphPoints[index],
                              ),
                            ),

                            color: widget.accent,
                            barWidth: 2,
                            isStrokeCapRound: true,

                            dotData: const FlDotData(show: false),

                            belowBarData: BarAreaData(
                              show: true,

                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,

                                colors: [
                                  widget.accent.withOpacity(0.18),
                                  widget.accent.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.title,

                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.value,

                    style: TextStyle(
                      fontSize: hovering ? 38 : 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.subtitle,

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
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
    );
  }
}
