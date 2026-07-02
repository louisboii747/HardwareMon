import 'package:flutter/material.dart';

import '../core/motion/motion.dart';

class RollingMetricText extends StatelessWidget {
  final String value;
  final TextStyle style;

  const RollingMetricText({
    super.key,
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: Motion.accessible(context, Motion.medium),
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) {
          final entering = Tween<Offset>(
            begin: const Offset(0, 0.38),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: entering, child: child),
          );
        },
        child: Text(
          value,
          key: ValueKey(value),
          style: style.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
