import 'package:flutter/material.dart';

import '../../services/alert_service.dart';
import '../core/theme/app_colors.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

enum MetricAlertKind {
  cpuUsage,
  ramUsage,
  diskUsage,
  cpuTemperature,
  gpuTemperature,
}

class MetricAlertConfiguration {
  final String label;
  final String unit;
  final double minimum;
  final double maximum;
  final double threshold;
  final bool enabled;

  const MetricAlertConfiguration({
    required this.label,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.threshold,
    required this.enabled,
  });
}

MetricAlertConfiguration metricAlertConfiguration(
  AppSettings settings,
  MetricAlertKind kind,
) {
  return switch (kind) {
    MetricAlertKind.cpuUsage => MetricAlertConfiguration(
      label: 'CPU usage',
      unit: '%',
      minimum: 50,
      maximum: 100,
      threshold: settings.cpuUsageThreshold,
      enabled: settings.cpuAlerts,
    ),
    MetricAlertKind.ramUsage => MetricAlertConfiguration(
      label: 'Memory usage',
      unit: '%',
      minimum: 50,
      maximum: 100,
      threshold: settings.ramUsageThreshold,
      enabled: settings.ramAlerts,
    ),
    MetricAlertKind.diskUsage => MetricAlertConfiguration(
      label: 'Disk usage',
      unit: '%',
      minimum: 50,
      maximum: 100,
      threshold: settings.diskUsageThreshold,
      enabled: settings.diskAlerts,
    ),
    MetricAlertKind.cpuTemperature => MetricAlertConfiguration(
      label: 'CPU temperature',
      unit: '°C',
      minimum: 50,
      maximum: 110,
      threshold: settings.cpuTemperatureThreshold,
      enabled: settings.temperatureAlerts,
    ),
    MetricAlertKind.gpuTemperature => MetricAlertConfiguration(
      label: 'GPU temperature',
      unit: '°C',
      minimum: 50,
      maximum: 110,
      threshold: settings.gpuTemperatureThreshold,
      enabled: settings.temperatureAlerts,
    ),
  };
}

AppSettings applyMetricAlertConfiguration({
  required AppSettings settings,
  required MetricAlertKind kind,
  required bool enabled,
  required double threshold,
}) {
  return switch (kind) {
    MetricAlertKind.cpuUsage => settings.copyWith(
      cpuAlerts: enabled,
      cpuUsageThreshold: threshold,
    ),
    MetricAlertKind.ramUsage => settings.copyWith(
      ramAlerts: enabled,
      ramUsageThreshold: threshold,
    ),
    MetricAlertKind.diskUsage => settings.copyWith(
      diskAlerts: enabled,
      diskUsageThreshold: threshold,
    ),
    MetricAlertKind.cpuTemperature => settings.copyWith(
      temperatureAlerts: enabled,
      cpuTemperatureThreshold: threshold,
    ),
    MetricAlertKind.gpuTemperature => settings.copyWith(
      temperatureAlerts: enabled,
      gpuTemperatureThreshold: threshold,
    ),
  };
}

Future<bool> showMetricAlertDialog({
  required BuildContext context,
  required MetricAlertKind kind,
  required double currentValue,
}) async {
  final settingsService = SettingsService();
  final settings = await settingsService.loadSettings();
  if (!context.mounted) return false;

  final configuration = metricAlertConfiguration(settings, kind);
  var enabled = configuration.enabled;
  var threshold = configuration.threshold.clamp(
    configuration.minimum,
    configuration.maximum,
  );

  final result = await showDialog<({bool enabled, double threshold})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Watch ${configuration.label}')),
          ],
        ),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HardwareMon will notify you when this metric reaches the selected threshold.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.overlay(context, 0.035),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Current',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${currentValue.toStringAsFixed(0)}${configuration.unit}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enable this watch',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) => setState(() => enabled = value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Alert threshold',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${threshold.round()}${configuration.unit}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: threshold,
                min: configuration.minimum,
                max: configuration.maximum,
                divisions: (configuration.maximum - configuration.minimum)
                    .round(),
                label: '${threshold.round()}${configuration.unit}',
                onChanged: enabled
                    ? (value) => setState(() => threshold = value)
                    : null,
              ),
              Text(
                enabled
                    ? 'The alert automatically rearms after the metric recovers.'
                    : 'The saved threshold is kept for when you enable this watch later.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pop((enabled: enabled, threshold: threshold)),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Apply watch'),
          ),
        ],
      ),
    ),
  );

  if (result == null) return false;

  final updated = applyMetricAlertConfiguration(
    settings: settings,
    kind: kind,
    enabled: result.enabled,
    threshold: result.threshold,
  );
  await settingsService.saveSettings(updated);
  AlertService.instance.updateSettings(updated);
  return true;
}
