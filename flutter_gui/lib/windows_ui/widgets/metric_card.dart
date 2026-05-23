import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'glass_panel.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
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

      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: hovering ? 1.01 : 1,

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

                    child: Icon(widget.icon, color: widget.accent, size: 20),
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
                    maxX: 6,
                    minY: 0,
                    maxY: 6,

                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),

                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,

                        spots: const [
                          FlSpot(0, 2),
                          FlSpot(1, 3),
                          FlSpot(2, 2.6),
                          FlSpot(3, 4),
                          FlSpot(4, 3.8),
                          FlSpot(5, 5),
                          FlSpot(6, 4.4),
                        ],

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
    );
  }
}
