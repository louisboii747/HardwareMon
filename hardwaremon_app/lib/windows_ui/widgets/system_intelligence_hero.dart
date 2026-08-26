import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/hardware_palette.dart';
import '../models/telemetry_insights.dart';
import '../models/monitoring_lens.dart';

class SystemIntelligenceHero extends StatelessWidget {
  final SystemHealthProfile profile;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenProcesses;
  final MonitoringLens lens;
  final ValueChanged<MonitoringLens>? onLensChanged;
  final VoidCallback? onSaveSnapshot;
  final VoidCallback? onOpenJournal;

  const SystemIntelligenceHero({
    super.key,
    required this.profile,
    required this.onOpenPerformance,
    required this.onOpenProcesses,
    this.lens = MonitoringLens.balanced,
    this.onLensChanged,
    this.onSaveSnapshot,
    this.onOpenJournal,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = HardwareStatusColors.forScore(profile.overallScore);

    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppColors.surface(context),
          border: Border.all(color: AppColors.rule(context)),
          boxShadow: const [],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: scoreColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final overview = _Overview(
                    profile: profile,
                    scoreColor: scoreColor,
                    onOpenPerformance: onOpenPerformance,
                    onOpenProcesses: onOpenProcesses,
                    lens: lens,
                    onLensChanged: onLensChanged,
                    onSaveSnapshot: onSaveSnapshot,
                    onOpenJournal: onOpenJournal,
                  );
                  final signals = _SignalGrid(profile: profile);

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ScoreDial(
                          score: profile.overallScore,
                          label: profile.stateLabel,
                          color: scoreColor,
                        ),
                        const SizedBox(width: 22),
                        Expanded(flex: 5, child: overview),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: signals),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _ScoreDial(
                            score: profile.overallScore,
                            label: profile.stateLabel,
                            color: scoreColor,
                            compact: true,
                          ),
                          const SizedBox(width: 18),
                          Expanded(child: overview),
                        ],
                      ),
                      const SizedBox(height: 18),
                      signals,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final SystemHealthProfile profile;
  final Color scoreColor;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenProcesses;
  final MonitoringLens lens;
  final ValueChanged<MonitoringLens>? onLensChanged;
  final VoidCallback? onSaveSnapshot;
  final VoidCallback? onOpenJournal;

  const _Overview({
    required this.profile,
    required this.scoreColor,
    required this.onOpenPerformance,
    required this.onOpenProcesses,
    required this.lens,
    required this.onLensChanged,
    required this.onSaveSnapshot,
    required this.onOpenJournal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 17, color: scoreColor),
            const SizedBox(width: 8),
            Text(
              'SYSTEM INTELLIGENCE',
              style: AppTypography.sectionLabel.copyWith(
                color: scoreColor,
                fontSize: 9,
              ),
            ),
            const Spacer(),
            _LensSelector(lens: lens, onChanged: onLensChanged),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          profile.observation,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.heading.copyWith(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.24,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.adjust_rounded, size: 14, color: scoreColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                profile.bottleneck,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroAction(
              label: 'Explore session',
              icon: Icons.monitor_heart_rounded,
              color: scoreColor,
              onTap: onOpenPerformance,
            ),
            _HeroAction(
              label: 'Find workload',
              icon: Icons.manage_search_rounded,
              color: HardwareDomain.cpu.color,
              onTap: onOpenProcesses,
            ),
            if (onSaveSnapshot != null)
              _HeroAction(
                label: 'Save snapshot',
                icon: Icons.bookmark_add_rounded,
                color: HardwareDomain.storage.color,
                onTap: onSaveSnapshot!,
              ),
            if (onOpenJournal != null)
              _HeroAction(
                label: 'Journal',
                icon: Icons.bookmarks_rounded,
                color: HardwareDomain.memory.color,
                onTap: onOpenJournal!,
              ),
          ],
        ),
      ],
    );
  }
}

class _LensSelector extends StatelessWidget {
  final MonitoringLens lens;
  final ValueChanged<MonitoringLens>? onChanged;

  const _LensSelector({required this.lens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MonitoringLens>(
      tooltip: 'Change monitoring lens',
      enabled: onChanged != null,
      initialValue: lens,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final candidate in MonitoringLens.values)
          PopupMenuItem(
            value: candidate,
            child: Row(
              children: [
                Icon(
                  candidate == lens
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 16,
                  color: candidate == lens
                      ? AppColors.accent
                      : AppColors.textMuted(context),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.label),
                      Text(
                        candidate.description,
                        style: TextStyle(
                          color: AppColors.textMuted(context),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_center_focus_rounded,
              size: 12,
              color: AppColors.accent,
            ),
            const SizedBox(width: 5),
            Text(
              lens.label,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.expand_more_rounded,
              size: 12,
              color: AppColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  final int score;
  final String label;
  final Color color;
  final bool compact;

  const _ScoreDial({
    required this.score,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 84.0 : 112.0;
    return Semantics(
      label: 'Overall system health $score out of 100, $label',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ScoreRingPainter(score: score, color: color),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Text(
                      '$score',
                      key: ValueKey(score),
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: compact ? 25 : 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: compact ? 7 : 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  final SystemHealthProfile profile;

  const _SignalGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 320 ? 2 : 1;
        final width = (constraints.maxWidth - (columns == 2 ? 8 : 0)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final signal in profile.signals)
              SizedBox(
                width: width,
                child: _SignalTile(signal: signal),
              ),
          ],
        );
      },
    );
  }
}

class _SignalTile extends StatelessWidget {
  final SystemHealthSignal signal;

  const _SignalTile({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = HardwareStatusColors.forScore(signal.score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: signal.score / 100,
                  strokeWidth: 2.5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
                Center(
                  child: Text(
                    '${signal.score}',
                    style: TextStyle(
                      color: color,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeroAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HeroAction> createState() => _HeroActionState();
}

class _HeroActionState extends State<_HeroAction> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _pressed ? 0.97 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.12)
                    : AppColors.controlFill(context),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: _hovered
                      ? widget.color.withValues(alpha: 0.42)
                      : AppColors.rule(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 14, color: widget.color),
                  const SizedBox(width: 7),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final int score;
  final Color color;

  const _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final inset = size.shortestSide * 0.06;
    final arcBounds = bounds.deflate(inset);
    final stroke = size.shortestSide * 0.055;
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.1);
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
      ..color = color;

    canvas.drawArc(arcBounds, -math.pi / 2, math.pi * 2, false, background);
    canvas.drawArc(
      arcBounds,
      -math.pi / 2,
      math.pi * 2 * score / 100,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
