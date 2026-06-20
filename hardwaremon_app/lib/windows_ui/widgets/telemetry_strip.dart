import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class SystemCondition {
  final String label;
  final String description;
  final Color color;
  final IconData icon;

  const SystemCondition({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });
}

SystemCondition evaluateSystemCondition({
  required int cpuUsage,
  required int ramUsage,
  required int cpuTemperature,
  required int gpuTemperature,
  required bool paused,
  required bool hasError,
}) {
  if (hasError) {
    return const SystemCondition(
      label: 'Connection issue',
      description: 'Telemetry needs attention',
      color: Colors.redAccent,
      icon: Icons.cloud_off_rounded,
    );
  }
  if (paused) {
    return const SystemCondition(
      label: 'Telemetry paused',
      description: 'Values are held',
      color: Colors.amber,
      icon: Icons.pause_rounded,
    );
  }

  final hottest = cpuTemperature > gpuTemperature
      ? cpuTemperature
      : gpuTemperature;
  final busiest = cpuUsage > ramUsage ? cpuUsage : ramUsage;

  if (hottest >= 88 || busiest >= 96) {
    return const SystemCondition(
      label: 'Under pressure',
      description: 'A resource is near its limit',
      color: Colors.redAccent,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (hottest >= 76 || busiest >= 82) {
    return const SystemCondition(
      label: 'Working hard',
      description: 'Sustained system activity',
      color: Colors.orangeAccent,
      icon: Icons.local_fire_department_rounded,
    );
  }
  if (busiest <= 24 && hottest < 58) {
    return const SystemCondition(
      label: 'Coasting',
      description: 'Plenty of headroom',
      color: Colors.lightBlueAccent,
      icon: Icons.air_rounded,
    );
  }
  return const SystemCondition(
    label: 'Balanced',
    description: 'System looks healthy',
    color: Colors.greenAccent,
    icon: Icons.eco_rounded,
  );
}

class TelemetryStrip extends StatelessWidget {
  final int cpuUsage;
  final int cpuTemperature;
  final int ramUsage;
  final int gpuUsage;
  final int gpuTemperature;
  final int diskUsage;
  final bool paused;
  final bool hasError;
  final VoidCallback onOpenPerformance;
  final VoidCallback onCopySnapshot;

  const TelemetryStrip({
    super.key,
    required this.cpuUsage,
    required this.cpuTemperature,
    required this.ramUsage,
    required this.gpuUsage,
    required this.gpuTemperature,
    required this.diskUsage,
    required this.paused,
    required this.hasError,
    required this.onOpenPerformance,
    required this.onCopySnapshot,
  });

  @override
  Widget build(BuildContext context) {
    final condition = evaluateSystemCondition(
      cpuUsage: cpuUsage,
      ramUsage: ramUsage,
      cpuTemperature: cpuTemperature,
      gpuTemperature: gpuTemperature,
      paused: paused,
      hasError: hasError,
    );

    return Semantics(
      button: true,
      label:
          '${condition.label}. CPU $cpuUsage percent, memory $ramUsage percent, GPU $gpuTemperature degrees.',
      child: Tooltip(
        message:
            '${condition.description}  •  Click for performance  •  Right-click to copy',
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onOpenPerformance,
            onSecondaryTap: onCopySnapshot,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface(context).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      _ConditionChip(condition: condition),
                      _MetricPulse(
                        label: 'CPU',
                        value: cpuUsage,
                        suffix: '%',
                        color: Colors.cyanAccent,
                      ),
                      _MetricPulse(
                        label: 'CPU TEMP',
                        value: cpuTemperature,
                        suffix: '°',
                        color: Colors.orangeAccent,
                        maximum: 100,
                      ),
                      _MetricPulse(
                        label: 'MEMORY',
                        value: ramUsage,
                        suffix: '%',
                        color: Colors.deepPurpleAccent,
                      ),
                      _MetricPulse(
                        label: 'GPU',
                        value: gpuUsage,
                        suffix: '%',
                        color: Colors.lightBlueAccent,
                      ),
                      _MetricPulse(
                        label: 'GPU TEMP',
                        value: gpuTemperature,
                        suffix: '°',
                        color: Colors.deepOrangeAccent,
                        maximum: 100,
                      ),
                      _MetricPulse(
                        label: 'DISK',
                        value: diskUsage,
                        suffix: '%',
                        color: Colors.tealAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final SystemCondition condition;

  const _ConditionChip({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: condition.color.withValues(alpha: 0.075),
        border: Border(right: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          _PulseDot(color: condition.color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    condition.label,
                    key: ValueKey(condition.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  condition.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _MetricPulse extends StatelessWidget {
  final String label;
  final num value;
  final String suffix;
  final Color color;
  final double maximum;

  const _MetricPulse({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    this.maximum = 100,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = (value.toDouble() / maximum).clamp(0.0, 1.0);
    final displayValue = value is double
        ? (value as double).toStringAsFixed(1)
        : value.toString();

    return Container(
      width: 104,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  '$displayValue$suffix',
                  key: ValueKey(displayValue),
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 2,
              color: AppColors.overlay(context, 0.05),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                widthFactor: normalized,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.55), color],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(
                alpha: 0.15 + (_controller.value * 0.3),
              ),
              blurRadius: 5 + (_controller.value * 7),
            ),
          ],
        ),
      ),
    );
  }
}
