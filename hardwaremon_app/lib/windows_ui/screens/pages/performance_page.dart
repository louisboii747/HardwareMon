import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chart_preferences.dart';
import '../../models/telemetry_insights.dart';
import '../../models/card_workspace.dart';
import '../../utils/telemetry_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/metric_alert_action.dart';
import '../../widgets/telemetry_studio.dart';
import '../../widgets/card_workspace.dart';

class PerformancePage extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;
  final CardWorkspacePreferences cardWorkspacePreferences;

  const PerformancePage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
    required this.cardWorkspacePreferences,
  });

  @override
  Widget build(BuildContext context) {
    final sessionAge = DateTime.now().difference(
      telemetry.sessionStatisticsStartedAt,
    );
    final sessionSummary = buildTelemetrySessionSummary(
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      gpuUsage: telemetry.gpuUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuHistory: telemetry.cpuHistory,
      ramHistory: telemetry.ramHistory,
      gpuHistory: telemetry.gpuUsageHistory,
      cpuTemperatureHistory: telemetry.cpuTempHistory,
      gpuTemperatureHistory: telemetry.gpuTempHistory,
      since: telemetry.sessionStatisticsStartedAt,
      paused: telemetry.isPaused,
      lastError: telemetry.lastError,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a card for details. Sections and cards support mouse, Tab, Enter, and Space.',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 12),
          ),
          const SizedBox(height: 16),
          _PerformanceControls(
            telemetry: telemetry,
            chartPreferences: chartPreferences,
          ),
          const SizedBox(height: 16),
          if (telemetry.isMacOS) ...[
            _MacOSCapabilityNotice(telemetry: telemetry),
            const SizedBox(height: 24),
          ] else ...[
            _SessionIntelligencePanel(
              summary: sessionSummary,
              sessionAge: sessionAge,
              telemetry: telemetry,
              onCopyReport: () =>
                  _copySessionReport(context, sessionSummary, sessionAge),
            ),
            const SizedBox(height: 24),
          ],
          if (!telemetry.isMacOS || telemetry.capabilities.supportsGpuUsage)
            TelemetryStudio(
              telemetry: telemetry,
              chartPreferences: chartPreferences,
            ),
          _PerformanceSection(
            preferences: cardWorkspacePreferences,
            title: 'CPU',
            icon: Icons.memory_rounded,
            accent: Colors.cyan,
            cards: [
              MetricCard(
                title: 'CPU Usage',
                value: '${telemetry.cpuUsage}%',
                subtitle: telemetry.cpuName,
                icon: Icons.memory_rounded,
                accent: Colors.cyan,
                graphPoints: telemetry.cpuHistory,
                chartPreferences: chartPreferences,
                statisticsSince: telemetry.sessionStatisticsStartedAt,
                alertKind: MetricAlertKind.cpuUsage,
                alertValue: telemetry.cpuUsage.toDouble(),
              ),
              if (telemetry.capabilities.supportsCpuTemperature)
                MetricCard(
                  title: 'CPU Temperature',
                  value: '${telemetry.cpuTemp}°C',
                  subtitle: 'CPU Package Temperature',
                  icon: Icons.thermostat_rounded,
                  accent: Colors.red,
                  graphPoints: telemetry.cpuTempHistory,
                  chartPreferences: chartPreferences,
                  metricKind: TelemetryMetricKind.temperature,
                  statisticsSince: telemetry.sessionStatisticsStartedAt,
                  alertKind: MetricAlertKind.cpuTemperature,
                  alertValue: telemetry.cpuTemp.toDouble(),
                ),
              if (telemetry.capabilities.supportsCpuFrequency)
                MetricCard(
                  title: 'CPU Clock',
                  value: '${telemetry.cpuClockGHz.toStringAsFixed(2)} GHz',
                  subtitle: 'Current clock speed',
                  icon: Icons.speed_rounded,
                  accent: Colors.green,
                  graphPoints: telemetry.cpuClockHistory,
                  chartPreferences: chartPreferences,
                  metricKind: TelemetryMetricKind.gigahertz,
                  statisticsSince: telemetry.sessionStatisticsStartedAt,
                ),
              if (telemetry.capabilities.supportsPowerMetrics)
                MetricCard(
                  title: 'CPU Power',
                  value: '${telemetry.cpuPower.toStringAsFixed(1)} W',
                  subtitle: 'Package power draw',
                  icon: Icons.bolt_rounded,
                  accent: Colors.amber,
                  graphPoints: telemetry.cpuPowerHistory,
                  chartPreferences: chartPreferences,
                  metricKind: TelemetryMetricKind.watts,
                  statisticsSince: telemetry.sessionStatisticsStartedAt,
                ),
            ],
          ),
          _PerformanceSection(
            preferences: cardWorkspacePreferences,
            title: 'Memory',
            icon: Icons.storage_rounded,
            accent: Colors.purple,
            cards: [
              MetricCard(
                title: 'RAM Usage',
                value: '${telemetry.ramUsage}%',
                subtitle: 'System memory usage',
                icon: Icons.storage_rounded,
                accent: Colors.purple,
                graphPoints: telemetry.ramHistory,
                chartPreferences: chartPreferences,
                statisticsSince: telemetry.sessionStatisticsStartedAt,
                alertKind: MetricAlertKind.ramUsage,
                alertValue: telemetry.ramUsage.toDouble(),
              ),
              MetricCard(
                title: 'RAM Used',
                value: '${telemetry.ramUsed.toStringAsFixed(1)} GB',
                subtitle: 'Currently allocated',
                icon: Icons.memory_rounded,
                accent: Colors.teal,
                graphPoints: telemetry.ramUsedHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
                statisticsSince: telemetry.sessionStatisticsStartedAt,
              ),
              MetricCard(
                title: 'RAM Available',
                value: '${telemetry.ramAvailable.toStringAsFixed(1)} GB',
                subtitle: 'Available memory',
                icon: Icons.check_circle_outline_rounded,
                accent: Colors.lightGreen,
                graphPoints: telemetry.ramAvailableHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
                statisticsSince: telemetry.sessionStatisticsStartedAt,
              ),
              MetricCard(
                title: 'Total RAM',
                value: '${telemetry.ramTotal.toStringAsFixed(1)} GB',
                subtitle: 'Installed memory',
                icon: Icons.dns_rounded,
                accent: Colors.indigo,
                graphPoints: telemetry.ramTotalHistory,
                chartPreferences: chartPreferences,
                metricKind: TelemetryMetricKind.gigabytes,
                statisticsSince: telemetry.sessionStatisticsStartedAt,
              ),
            ],
          ),
          if (telemetry.capabilities.supportsGpuTemperature ||
              telemetry.capabilities.supportsGpuUsage ||
              telemetry.capabilities.supportsPowerMetrics ||
              telemetry.capabilities.supportsGpuVram)
            _PerformanceSection(
              preferences: cardWorkspacePreferences,
              title: 'GPU',
              icon: Icons.graphic_eq_rounded,
              accent: Colors.orange,
              cards: [
                if (telemetry.capabilities.supportsGpuTemperature)
                  MetricCard(
                    title: 'GPU Temperature',
                    value: '${telemetry.gpuTemp}°C',
                    subtitle: 'Live telemetry',
                    icon: Icons.graphic_eq_rounded,
                    accent: Colors.orange,
                    graphPoints: telemetry.gpuTempHistory,
                    chartPreferences: chartPreferences,
                    metricKind: TelemetryMetricKind.temperature,
                    statisticsSince: telemetry.sessionStatisticsStartedAt,
                    alertKind: MetricAlertKind.gpuTemperature,
                    alertValue: telemetry.gpuTemp.toDouble(),
                  ),
                if (telemetry.capabilities.supportsGpuUsage)
                  MetricCard(
                    title: 'GPU Usage',
                    value: '${telemetry.gpuUsage}%',
                    subtitle: 'Current GPU load',
                    icon: Icons.show_chart_rounded,
                    accent: Colors.blue,
                    graphPoints: telemetry.gpuUsageHistory,
                    chartPreferences: chartPreferences,
                    statisticsSince: telemetry.sessionStatisticsStartedAt,
                  ),
                if (telemetry.capabilities.supportsPowerMetrics)
                  MetricCard(
                    title: 'GPU Power',
                    value: '${telemetry.gpuPower.toStringAsFixed(1)} W',
                    subtitle: 'Board power draw',
                    icon: Icons.bolt_rounded,
                    accent: const Color.fromARGB(255, 115, 255, 0),
                    graphPoints: telemetry.gpuPowerHistory,
                    chartPreferences: chartPreferences,
                    metricKind: TelemetryMetricKind.watts,
                    statisticsSince: telemetry.sessionStatisticsStartedAt,
                  ),
                if (telemetry.capabilities.supportsGpuVram)
                  MetricCard(
                    title: 'VRAM Used',
                    value: '${telemetry.gpuVramUsed.toStringAsFixed(1)} GB',
                    subtitle: 'Graphics memory usage',
                    icon: Icons.memory_rounded,
                    accent: Colors.purple,
                    graphPoints: telemetry.gpuVramUsedHistory,
                    chartPreferences: chartPreferences,
                    metricKind: TelemetryMetricKind.gigabytes,
                    statisticsSince: telemetry.sessionStatisticsStartedAt,
                  ),
              ],
            ),
          _PerformanceSection(
            preferences: cardWorkspacePreferences,
            title: 'Historical Analytics',
            icon: Icons.timeline_rounded,
            accent: AppColors.accent,
            preferredColumns: 3,
            cards: [
              MetricCard(
                title: 'CPU History',
                value: '${telemetry.historicalCpuHistory.length}',
                subtitle: 'Timestamped samples',
                icon: Icons.timeline_rounded,
                accent: Colors.cyan,
                graphPoints: telemetry.historicalCpuHistory,
                chartPreferences: chartPreferences,
              ),
              MetricCard(
                title: 'Memory History',
                value: '${telemetry.historicalRamHistory.length}',
                subtitle: 'Timestamped samples',
                icon: Icons.storage_rounded,
                accent: Colors.purple,
                graphPoints: telemetry.historicalRamHistory,
                chartPreferences: chartPreferences,
              ),
              if (telemetry.capabilities.supportsGpuUsage)
                MetricCard(
                  title: 'GPU History',
                  value: '${telemetry.historicalGpuHistory.length}',
                  subtitle: 'Timestamped samples',
                  icon: Icons.graphic_eq_rounded,
                  accent: Colors.orange,
                  graphPoints: telemetry.historicalGpuHistory,
                  chartPreferences: chartPreferences,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copySessionReport(
    BuildContext context,
    TelemetrySessionSummary summary,
    Duration sessionAge,
  ) async {
    final lines = [
      'HardwareMon Performance Session',
      'Captured: ${DateTime.now().toIso8601String()}',
      'Score: ${summary.score}/100 · ${summary.headline}',
      'Detail: ${summary.detail}',
      '',
      'CPU: current ${telemetry.cpuUsage}%, avg ${summary.cpuAverage.toStringAsFixed(1)}%, peak ${summary.cpuPeak.toStringAsFixed(1)}%',
      'Memory: current ${telemetry.ramUsage}%, avg ${summary.ramAverage.toStringAsFixed(1)}%, peak ${summary.ramPeak.toStringAsFixed(1)}%',
      'GPU: current ${telemetry.gpuUsage}%, avg ${summary.gpuAverage.toStringAsFixed(1)}%, peak ${summary.gpuPeak.toStringAsFixed(1)}%',
      'Thermals: CPU peak ${summary.cpuTemperaturePeak.toStringAsFixed(0)}°C, GPU peak ${summary.gpuTemperaturePeak.toStringAsFixed(0)}°C',
      'Headroom: memory ${_formatHeadroomPercent(summary.memoryHeadroom)}, thermal ${_formatHeadroomTemperature(summary.thermalHeadroom)}',
      'Session age: ${_formatSessionAge(sessionAge)}',
      'Samples: ${summary.sampleCount}',
      '',
      'Insights:',
      for (final insight in summary.insights)
        '- ${insight.title}: ${insight.detail}',
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance session report copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _MacOSCapabilityNotice extends StatelessWidget {
  final TelemetryService telemetry;

  const _MacOSCapabilityNotice({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final platform = telemetry.platformInfo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withValues(alpha: 0.09),
            AppColors.surface(context),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.laptop_mac_rounded, color: Colors.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${telemetry.cpuName} · ${platform?.architecture ?? 'Apple Silicon'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'CPU and memory monitoring are active. macOS does not expose every temperature, fan, power, or detailed GPU sensor through stable public APIs, so HardwareMon hides unavailable cards instead of inventing readings.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _CapabilityPill(label: 'CPU usage', available: true),
                    _CapabilityPill(label: 'Memory', available: true),
                    _CapabilityPill(label: 'Sensors', available: false),
                    _CapabilityPill(label: 'Power', available: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityPill extends StatelessWidget {
  final String label;
  final bool available;

  const _CapabilityPill({required this.label, required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? Colors.greenAccent : Colors.orangeAccent;
    return Tooltip(
      message: available
          ? '$label is available on macOS'
          : '$label is not reported by the current macOS integration',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Text(
          '${available ? 'Available' : 'Limited'} · $label',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SessionIntelligencePanel extends StatelessWidget {
  final TelemetrySessionSummary summary;
  final Duration sessionAge;
  final TelemetryService telemetry;
  final VoidCallback onCopyReport;

  const _SessionIntelligencePanel({
    required this.summary,
    required this.sessionAge,
    required this.telemetry,
    required this.onCopyReport,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(summary.score);
    return Semantics(
      container: true,
      label:
          'Session intelligence. Score ${summary.score} out of 100. ${summary.headline}. Memory headroom ${_formatHeadroomPercent(summary.memoryHeadroom)}. Thermal headroom ${_formatHeadroomTemperature(summary.thermalHeadroom)}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: scoreColor.withValues(alpha: 0.055),
              blurRadius: 28,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            final score = _SessionScore(
              score: summary.score,
              label: summary.headline,
              detail: summary.detail,
              color: scoreColor,
            );
            final metrics = _SessionMetricGrid(
              summary: summary,
              sessionAge: sessionAge,
            );
            final insights = _SessionInsightList(insights: summary.insights);

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  score,
                  const SizedBox(height: 16),
                  metrics,
                  const SizedBox(height: 16),
                  insights,
                  const SizedBox(height: 14),
                  _SessionActions(
                    telemetry: telemetry,
                    onCopyReport: onCopyReport,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 235, child: score),
                Container(
                  width: 1,
                  height: 185,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: AppColors.border(context),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      metrics,
                      const SizedBox(height: 14),
                      _SessionActions(
                        telemetry: telemetry,
                        onCopyReport: onCopyReport,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: insights),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionScore extends StatelessWidget {
  final int score;
  final String label;
  final String detail;
  final Color color;

  const _SessionScore({
    required this.score,
    required this.label,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => SizedBox.square(
            dimension: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: AppColors.overlay(context, 0.06),
                ),
                Text(
                  '${(value * 100).round()}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session intelligence',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionMetricGrid extends StatelessWidget {
  final TelemetrySessionSummary summary;
  final Duration sessionAge;

  const _SessionMetricGrid({required this.summary, required this.sessionAge});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _SessionMetric(
        label: 'CPU avg / peak',
        value:
            '${summary.cpuAverage.toStringAsFixed(0)}% / ${summary.cpuPeak.toStringAsFixed(0)}%',
        icon: Icons.memory_rounded,
        color: Colors.cyanAccent,
      ),
      _SessionMetric(
        label: 'RAM avg / peak',
        value:
            '${summary.ramAverage.toStringAsFixed(0)}% / ${summary.ramPeak.toStringAsFixed(0)}%',
        icon: Icons.storage_rounded,
        color: Colors.purpleAccent,
      ),
      _SessionMetric(
        label: 'Thermal peak',
        value:
            '${summary.cpuTemperaturePeak.toStringAsFixed(0)}° / ${summary.gpuTemperaturePeak.toStringAsFixed(0)}°',
        icon: Icons.device_thermostat_rounded,
        color: Colors.orangeAccent,
      ),
      _SessionMetric(
        label: 'Headroom',
        value:
            '${_formatHeadroomPercent(summary.memoryHeadroom)} / ${_formatHeadroomTemperature(summary.thermalHeadroom)}',
        icon: Icons.health_and_safety_rounded,
        color: Colors.greenAccent,
      ),
      _SessionMetric(
        label: 'Samples',
        value: summary.sampleCount.toString(),
        icon: Icons.timeline_rounded,
        color: Colors.lightGreenAccent,
      ),
      _SessionMetric(
        label: 'Session age',
        value: _formatSessionAge(sessionAge),
        icon: Icons.timer_rounded,
        color: Colors.lightBlueAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _SessionMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _SessionMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SessionMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _SessionMetricCard extends StatelessWidget {
  final _SessionMetric metric;

  const _SessionMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${metric.label}: ${metric.value}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: metric.color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: metric.color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: metric.color, size: 17),
            const SizedBox(height: 9),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label,
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
    );
  }
}

class _SessionInsightList extends StatelessWidget {
  final List<TelemetryInsight> insights;

  const _SessionInsightList({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Live recommendations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${insights.length}',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < insights.length; index++) ...[
          _SessionInsightTile(insight: insights[index]),
          if (index != insights.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SessionInsightTile extends StatelessWidget {
  final TelemetryInsight insight;

  const _SessionInsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = _insightColor(insight.severity);
    final icon = switch (insight.severity) {
      TelemetryInsightSeverity.healthy => Icons.check_circle_outline_rounded,
      TelemetryInsightSeverity.info => Icons.info_outline_rounded,
      TelemetryInsightSeverity.warning => Icons.warning_amber_rounded,
      TelemetryInsightSeverity.critical => Icons.report_gmailerrorred_rounded,
    };

    return Semantics(
      label: '${insight.title}. ${insight.detail}',
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    insight.detail,
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 9,
                      height: 1.35,
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

class _SessionActions extends StatelessWidget {
  final TelemetryService telemetry;
  final VoidCallback onCopyReport;

  const _SessionActions({required this.telemetry, required this.onCopyReport});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onCopyReport,
          icon: const Icon(Icons.content_copy_rounded, size: 16),
          label: const Text('Copy report'),
        ),
        OutlinedButton.icon(
          onPressed: telemetry.isRefreshing
              ? null
              : () => telemetry.refreshNow(includeHistory: true),
          icon: telemetry.isRefreshing
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh now'),
        ),
        OutlinedButton.icon(
          onPressed: telemetry.togglePaused,
          icon: Icon(
            telemetry.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 16,
          ),
          label: Text(telemetry.isPaused ? 'Resume' : 'Pause'),
        ),
        OutlinedButton.icon(
          onPressed: telemetry.resetSessionStatistics,
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('Reset session'),
        ),
      ],
    );
  }
}

class _PerformanceControls extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;

  const _PerformanceControls({
    required this.telemetry,
    required this.chartPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _PreferenceSwitch(
            label: 'Live',
            icon: telemetry.isPaused
                ? Icons.pause_circle_outline_rounded
                : Icons.sensors_rounded,
            value: !telemetry.isPaused,
            onChanged: (value) => telemetry.setPaused(!value),
          ),
          _PreferenceSwitch(
            label: 'Smooth curves',
            icon: Icons.gesture_rounded,
            value: chartPreferences.smoothLines,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.smoothLines,
              value,
            ),
          ),
          _PreferenceSwitch(
            label: 'Area fill',
            icon: Icons.gradient_rounded,
            value: chartPreferences.areaFill,
            onChanged: (value) =>
                chartPreferences.setPreference(ChartPreference.areaFill, value),
          ),
          _PreferenceSwitch(
            label: 'Grid',
            icon: Icons.grid_4x4_rounded,
            value: chartPreferences.gridLines,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.gridLines,
              value,
            ),
          ),
          _PreferenceSwitch(
            label: 'Motion',
            icon: Icons.animation_rounded,
            value: chartPreferences.animations,
            onChanged: (value) => chartPreferences.setPreference(
              ChartPreference.animations,
              value,
            ),
          ),
          Tooltip(
            message: 'Fetch telemetry and history now  •  Ctrl+R',
            child: OutlinedButton.icon(
              onPressed: telemetry.isRefreshing
                  ? null
                  : () => telemetry.refreshNow(includeHistory: true),
              icon: telemetry.isRefreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
                side: BorderSide(color: AppColors.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Reset session minimum, maximum, and average values',
            child: OutlinedButton.icon(
              onPressed: telemetry.resetSessionStatistics,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset stats'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
                side: BorderSide(color: AppColors.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: value
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.overlay(context, 0.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: value ? AppColors.accent : AppColors.textMuted(context),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> cards;
  final int preferredColumns;
  final CardWorkspacePreferences preferences;

  const _PerformanceSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.cards,
    required this.preferences,
    this.preferredColumns = 2,
  });

  @override
  State<_PerformanceSection> createState() => _PerformanceSectionState();
}

class _PerformanceSectionState extends State<_PerformanceSection> {
  bool expanded = true;
  bool hovering = false;
  bool focused = false;

  void _toggle() => setState(() => expanded = !expanded);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused
              ? widget.accent.withValues(alpha: 0.6)
              : AppColors.border(context),
          width: focused ? 1.5 : 1,
        ),
        boxShadow: hovering
            ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.06),
                  blurRadius: 28,
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '${widget.title} section. ${expanded ? 'Collapse' : 'Expand'}.',
            child: FocusableActionDetector(
              mouseCursor: SystemMouseCursors.click,
              onShowFocusHighlight: (value) => setState(() => focused = value),
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _toggle();
                    return null;
                  },
                ),
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => hovering = true),
                onExit: (_) => setState(() => hovering = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(
                              alpha: hovering || focused ? 0.16 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${widget.cards.length} metrics',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: expanded ? 0 : -0.25,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      CardWorkspace(
                        pageId:
                            'performance-${widget.title.toLowerCase().replaceAll(' ', '-')}',
                        pageLabel: '${widget.title} metrics',
                        preferences: widget.preferences,
                        standardHeight: 245,
                        showToolbar: true,
                        cards: [
                          for (
                            var index = 0;
                            index < widget.cards.length;
                            index++
                          )
                            WorkspaceCard(
                              id: 'metric-$index',
                              title: '${widget.title} metric ${index + 1}',
                              child: widget.cards[index],
                            ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// Retained for focused legacy section tests and compatibility with extensions.
// ignore: unused_element
class _ResponsiveMetricGrid extends StatelessWidget {
  final List<Widget> cards;
  final int preferredColumns;

  const _ResponsiveMetricGrid({
    required this.cards,
    required this.preferredColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final responsiveColumns = availableWidth >= 1040
            ? 3
            : availableWidth >= 620
            ? 2
            : 1;
        final columns = responsiveColumns.clamp(1, preferredColumns);
        final aspectRatio = columns == 1
            ? 1.75
            : columns == 2
            ? 1.6
            : 1.4;

        return GridView.builder(
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 86) return Colors.greenAccent;
  if (score >= 68) return Colors.cyanAccent;
  if (score >= 48) return Colors.orangeAccent;
  return Colors.redAccent;
}

Color _insightColor(TelemetryInsightSeverity severity) {
  return switch (severity) {
    TelemetryInsightSeverity.healthy => Colors.greenAccent,
    TelemetryInsightSeverity.info => Colors.cyanAccent,
    TelemetryInsightSeverity.warning => Colors.orangeAccent,
    TelemetryInsightSeverity.critical => Colors.redAccent,
  };
}

String _formatHeadroomPercent(double value) {
  if (!value.isFinite) return 'Unavailable';
  return '${value.clamp(0, 100).round()}%';
}

String _formatHeadroomTemperature(double value) {
  if (!value.isFinite) return 'Unavailable';
  return '${value.clamp(0, 95).round()}°C';
}

String _formatSessionAge(Duration duration) {
  if (duration.inHours >= 1) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes}m';
  }
  if (duration.inMinutes >= 1) {
    final seconds = duration.inSeconds.remainder(60);
    return '${duration.inMinutes}m ${seconds}s';
  }
  return '${duration.inSeconds.clamp(0, 59)}s';
}
