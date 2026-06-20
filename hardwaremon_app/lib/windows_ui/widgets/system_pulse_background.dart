import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class SystemPulseBackground extends StatelessWidget {
  final int cpuUsage;
  final int ramUsage;
  final int gpuTemperature;
  final bool enabled;

  const SystemPulseBackground({
    super.key,
    required this.cpuUsage,
    required this.ramUsage,
    required this.gpuTemperature,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final lightMultiplier = AppColors.isLight(context) ? 0.7 : 1.0;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ActivityGlow(
              alignment: const Alignment(-1.08, -1.12),
              color: Colors.cyanAccent,
              activity: cpuUsage / 100,
              baseSize: 430,
              opacityMultiplier: lightMultiplier,
            ),
            _ActivityGlow(
              alignment: const Alignment(1.16, 1.18),
              color: Colors.deepPurpleAccent,
              activity: ramUsage / 100,
              baseSize: 500,
              opacityMultiplier: lightMultiplier,
            ),
            _ActivityGlow(
              alignment: const Alignment(0.42, -0.72),
              color: gpuTemperature >= 75
                  ? Colors.redAccent
                  : Colors.orangeAccent,
              activity: ((gpuTemperature - 30) / 70).clamp(0, 1),
              baseSize: 350,
              opacityMultiplier: lightMultiplier,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityGlow extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double activity;
  final double baseSize;
  final double opacityMultiplier;

  const _ActivityGlow({
    required this.alignment,
    required this.color,
    required this.activity,
    required this.baseSize,
    required this.opacityMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = activity.clamp(0.0, 1.0);
    final size = baseSize * (0.82 + (normalized * 0.34));
    final opacity = (0.025 + (normalized * 0.075)) * opacityMultiplier;

    return Align(
      alignment: alignment,
      child: AnimatedScale(
        scale: 0.9 + (normalized * 0.16),
        duration: const Duration(milliseconds: 950),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 950),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.26),
                Colors.transparent,
              ],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
      ),
    );
  }
}
