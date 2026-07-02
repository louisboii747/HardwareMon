import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/motion/motion.dart';

class GlassPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double opacity;
  final bool interactive;
  final Color? glowColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.blur = 20,
    this.opacity = 0.75,
    this.interactive = true,
    this.glowColor,
  });

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.interactive && _hovering;
    final glow = widget.glowColor ?? AppColors.accent;
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: widget.interactive
            ? (_) => setState(() => _hovering = true)
            : null,
        onExit: widget.interactive
            ? (_) => setState(() => _hovering = false)
            : null,
        child: AnimatedSlide(
          offset: Offset(0, _hovering ? -0.02 : 0),
          duration: Motion.accessible(context, Motion.fast),
          curve: Motion.emphasized,
          child: AnimatedContainer(
            duration: Motion.accessible(context, Motion.fast),
            curve: Motion.emphasized,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),

              boxShadow: [
                BoxShadow(
                  color: active
                      ? glow.withValues(alpha: 0.14)
                      : AppColors.shadow(context),
                  blurRadius: active ? 32 : 18,
                  spreadRadius: active ? 1 : 0,
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),

              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blur,
                  sigmaY: widget.blur,
                ),

                child: Container(
                  padding: widget.padding,

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        active
                            ? glow.withValues(alpha: 0.055)
                            : AppColors.overlay(context, 0.012),
                        AppColors.surface(
                          context,
                        ).withValues(alpha: widget.opacity.clamp(0, 1)),
                      ],
                    ),

                    borderRadius: BorderRadius.circular(AppRadius.lg),

                    border: Border.all(
                      color: AppColors.border(context),
                      width: 1,
                    ),
                  ),

                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
