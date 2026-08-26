import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A restrained live edge marker for people who keep ambient effects enabled.
/// It replaces the old radial glow field without turning telemetry into decor.
class SystemPulseBackground extends StatelessWidget {
  final int cpuUsage;
  final int ramUsage;
  final int gpuTemperature;
  final bool enabled;
  final double intensity;

  const SystemPulseBackground({
    super.key,
    required this.cpuUsage,
    required this.ramUsage,
    required this.gpuTemperature,
    required this.enabled,
    this.intensity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final animationsOff =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final opacity = (0.24 * intensity.clamp(0, 1.5)).clamp(0.0, 0.36);
    final cpuWidth = (0.12 + (cpuUsage / 100 * 0.42)).clamp(0.12, 0.54);
    final ramWidth = (0.1 + (ramUsage / 100 * 0.32)).clamp(0.1, 0.42);
    final thermalColor = gpuTemperature >= 76
        ? AppColors.warningRed
        : AppColors.accent;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: enabled ? opacity : 0,
        duration: animationsOff
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: AnimatedFractionallySizedBox(
                duration: animationsOff
                    ? Duration.zero
                    : const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                widthFactor: cpuWidth,
                child: Container(height: 1, color: AppColors.accent),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: AnimatedFractionallySizedBox(
                duration: animationsOff
                    ? Duration.zero
                    : const Duration(milliseconds: 620),
                curve: Curves.easeOutCubic,
                widthFactor: ramWidth,
                child: Container(height: 1, color: thermalColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
