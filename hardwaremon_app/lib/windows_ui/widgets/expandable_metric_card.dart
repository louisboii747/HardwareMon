import 'package:flutter/material.dart';

import '../models/chart_preferences.dart';
import '../models/telemetry_sample.dart';
import '../screens/metric_focus_screen.dart';
import '../utils/telemetry_chart.dart';

class ExpandableMetricCard extends StatelessWidget {
  final Widget closedChild;

  final String title;
  final String value;
  final String subtitle;

  final IconData icon;
  final Color accent;

  final List<double> graphPoints;
  final ChartPreferences chartPreferences;

  ExpandableMetricCard({
    super.key,
    required this.closedChild,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.graphPoints,
    ChartPreferences? chartPreferences,
  }) : chartPreferences = chartPreferences ?? ChartPreferences();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(24),

        onTap: () {
          Navigator.push(
            context,

            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 700),
              reverseTransitionDuration: const Duration(milliseconds: 500),

              opaque: false,

              pageBuilder: (_, _, _) {
                final now = DateTime.now();
                final timestampedPoints = graphPoints
                    .asMap()
                    .entries
                    .map(
                      (entry) => TelemetrySample(
                        timestamp: now.subtract(
                          Duration(
                            seconds: (graphPoints.length - entry.key - 1) * 5,
                          ),
                        ),
                        value: entry.value,
                      ),
                    )
                    .toList(growable: false);

                return MetricFocusScreen(
                  title: title,
                  value: value,
                  subtitle: subtitle,
                  icon: icon,
                  accent: accent,
                  graphPoints: timestampedPoints,
                  chartPreferences: chartPreferences,
                  metricKind: title.toLowerCase().contains('temp')
                      ? TelemetryMetricKind.temperature
                      : TelemetryMetricKind.percentage,
                );
              },

              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,

                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),

                        child: child,
                      ),
                    );
                  },
            ),
          );
        },

        child: closedChild,
      ),
    );
  }
}
