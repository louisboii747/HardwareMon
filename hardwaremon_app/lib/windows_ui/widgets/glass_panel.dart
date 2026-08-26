import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

/// Shared work-sheet surface used throughout the desktop UI.
///
/// The class name remains stable so feature pages keep their existing widget
/// contracts while the old glass treatment is replaced across the app.
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
    this.padding = const EdgeInsets.all(20),
    this.blur = 0,
    this.opacity = 1,
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
    final hovering = widget.interactive && _hovering;
    final selectedRule = widget.glowColor ?? AppColors.accent;
    final base = AppColors.surface(context);
    final hover = Color.alphaBlend(
      selectedRule.withValues(alpha: 0.035),
      AppColors.surfaceElevated(context),
    );

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: widget.interactive
            ? (_) => setState(() => _hovering = true)
            : null,
        onExit: widget.interactive
            ? (_) => setState(() => _hovering = false)
            : null,
        child: AnimatedContainer(
          duration: Motion.accessible(context, Motion.fast),
          curve: Motion.emphasized,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: hovering ? hover : base,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.rule(context)),
          ),
          child: Material(type: MaterialType.transparency, child: widget.child),
        ),
      ),
    );
  }
}
