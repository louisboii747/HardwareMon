import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

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
  required int? cpuTemperature,
  required int? gpuTemperature,
  required bool paused,
  required bool hasError,
}) {
  if (hasError) {
    return const SystemCondition(
      label: 'Connection issue',
      description: 'Telemetry needs attention',
      color: AppColors.warningRed,
      icon: Icons.cloud_off_rounded,
    );
  }
  if (paused) {
    return const SystemCondition(
      label: 'Telemetry paused',
      description: 'Values are held',
      color: Color(0xFF987126),
      icon: Icons.pause_rounded,
    );
  }

  final temperatures = [?cpuTemperature, ?gpuTemperature];
  final hottest = temperatures.isEmpty
      ? null
      : temperatures.reduce((a, b) => a > b ? a : b);
  final busiest = cpuUsage > ramUsage ? cpuUsage : ramUsage;

  if ((hottest != null && hottest >= 88) || busiest >= 96) {
    return const SystemCondition(
      label: 'Under pressure',
      description: 'A resource is near its limit',
      color: AppColors.warningRed,
      icon: Icons.warning_amber_rounded,
    );
  }
  if ((hottest != null && hottest >= 76) || busiest >= 82) {
    return const SystemCondition(
      label: 'Working hard',
      description: 'Sustained system activity',
      color: Color(0xFF987126),
      icon: Icons.local_fire_department_rounded,
    );
  }
  if (busiest <= 24 && (hottest == null || hottest < 58)) {
    return const SystemCondition(
      label: 'Coasting',
      description: 'Plenty of headroom',
      color: AppColors.workOrderBlue,
      icon: Icons.air_rounded,
    );
  }
  return const SystemCondition(
    label: 'Balanced',
    description: 'System looks healthy',
    color: AppColors.healthyGreen,
    icon: Icons.check_rounded,
  );
}

class TelemetryStrip extends StatelessWidget {
  final int cpuUsage;
  final int? cpuTemperature;
  final int ramUsage;
  final int? gpuUsage;
  final int? gpuTemperature;
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
          '${condition.label}. CPU $cpuUsage percent, memory $ramUsage percent, GPU ${gpuTemperature == null ? 'temperature unavailable' : '$gpuTemperature degrees'}.',
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
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(
                  bottom: BorderSide(color: AppColors.rule(context)),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    _ConditionCell(condition: condition),
                    _MetricCell(
                      label: 'CPU LOAD',
                      value: cpuUsage,
                      suffix: '%',
                    ),
                    _MetricCell(
                      label: 'CPU TEMP',
                      value: cpuTemperature,
                      suffix: '°',
                    ),
                    _MetricCell(label: 'MEMORY', value: ramUsage, suffix: '%'),
                    _MetricCell(
                      label: 'GPU LOAD',
                      value: gpuUsage,
                      suffix: '%',
                    ),
                    _MetricCell(
                      label: 'GPU TEMP',
                      value: gpuTemperature,
                      suffix: '°',
                    ),
                    _MetricCell(label: 'DISK', value: diskUsage, suffix: '%'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConditionCell extends StatelessWidget {
  final SystemCondition condition;

  const _ConditionCell({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 54,
      padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
      decoration: BoxDecoration(
        color: condition.color.withValues(alpha: 0.065),
        border: Border(right: BorderSide(color: AppColors.rule(context))),
      ),
      child: Row(
        children: [
          _StatusBracket(color: condition.color),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Column(
                key: ValueKey(condition.label),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    condition.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata.copyWith(
                      color: AppColors.textMuted(context),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final num? value;
  final String suffix;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? '—'
        : value is double
        ? (value as double).toStringAsFixed(1)
        : value.toString();

    return Container(
      width: 108,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.rule(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionLabel.copyWith(
                color: AppColors.textMuted(context),
                fontSize: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 170),
            child: Text(
              '$display${value == null ? '' : suffix}',
              key: ValueKey(display),
              style: AppTypography.metric.copyWith(
                color: AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBracket extends StatelessWidget {
  final Color color;

  const _StatusBracket({required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 7,
      height: 29,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 2),
          top: BorderSide(color: color, width: 2),
          bottom: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}
