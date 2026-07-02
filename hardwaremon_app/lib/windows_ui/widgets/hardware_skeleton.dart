import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class HardwareSkeletonCard extends StatefulWidget {
  const HardwareSkeletonCard({super.key});

  @override
  State<HardwareSkeletonCard> createState() => _HardwareSkeletonCardState();
}

class _HardwareSkeletonCardState extends State<HardwareSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _controller.isAnimating) _controller.stop();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = reduceMotion ? 0.4 : _controller.value;
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border(context)),
              gradient: LinearGradient(
                begin: Alignment(-1.4 + phase * 2.8, -0.4),
                end: Alignment(-0.2 + phase * 2.8, 0.4),
                colors: [
                  AppColors.surface(context),
                  AppColors.overlay(context, 0.065),
                  AppColors.surface(context),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(width: 42, height: 42, radius: 13),
                Spacer(),
                _SkeletonBlock(width: 92, height: 11, radius: 6),
                SizedBox(height: 10),
                _SkeletonBlock(width: 126, height: 34, radius: 8),
                SizedBox(height: 10),
                _SkeletonBlock(width: 176, height: 9, radius: 5),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.075),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
