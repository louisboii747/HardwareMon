import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

class GlassPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double opacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.blur = 20,
    this.opacity = 0.75,
  });

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        offset: Offset(0, _hovering ? -0.02 : 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),

            boxShadow: [
              BoxShadow(
                color: _hovering ? AppColors.glow : AppColors.shadow(context),
                blurRadius: _hovering ? 32 : 18,
                spreadRadius: _hovering ? 1 : 0,
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
                  color: AppColors.surface(context),

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
    );
  }
}
