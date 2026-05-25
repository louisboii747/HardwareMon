import 'package:flutter/material.dart';

import '../screens/metric_focus_screen.dart';

class ExpandableMetricCard extends StatelessWidget {
  final Widget closedChild;

  final String title;
  final String value;
  final String subtitle;

  final IconData icon;
  final Color accent;

  final List<double> graphPoints;

  const ExpandableMetricCard({
    super.key,
    required this.closedChild,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.graphPoints,
  });

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

              pageBuilder: (_, __, ___) {
                return MetricFocusScreen(
                  title: title,
                  value: value,
                  subtitle: subtitle,
                  icon: icon,
                  accent: accent,
                  graphPoints: graphPoints,
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
