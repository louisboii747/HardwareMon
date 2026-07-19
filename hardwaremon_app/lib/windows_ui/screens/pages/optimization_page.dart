import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chart_preferences.dart';
import '../../models/optimization_models.dart';
import '../../models/storage_models.dart';
import '../../models/telemetry_sample.dart';
import '../../services/optimization_service.dart';
import '../../services/storage_service.dart';
import '../../services/telemetry_service.dart';
import '../../widgets/glass_panel.dart';

class OptimizationPage extends StatefulWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;
  final VoidCallback onOpenProcesses;
  final VoidCallback onOpenStorage;
  final OptimizationService? optimizationService;
  final StorageService? storageService;

  const OptimizationPage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
    required this.onOpenProcesses,
    required this.onOpenStorage,
    this.optimizationService,
    this.storageService,
  });

  @override
  State<OptimizationPage> createState() => _OptimizationPageState();
}

class _OptimizationPageState extends State<OptimizationPage> {
  late final OptimizationService _optimizationService;
  late final StorageService _storageService;

  OptimizationSnapshot? _optimization;
  StorageSnapshot? _storage;
  StorageHistory? _storageHistory;
  String? _error;
  bool _loading = true;
  String? _changingStartupId;

  @override
  void initState() {
    super.initState();
    _optimizationService = widget.optimizationService ?? OptimizationService();
    _storageService = widget.storageService ?? StorageService();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        _optimizationService.fetchSnapshot(),
        _storageService.fetchSnapshot(),
        _storageService.fetchHistory(points: 180),
      ]);
      if (!mounted) return;
      setState(() {
        _optimization = results[0] as OptimizationSnapshot;
        _storage = results[1] as StorageSnapshot;
        _storageHistory = results[2] as StorageHistory;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStartupEnabled(StartupApplication app, bool enabled) async {
    setState(() => _changingStartupId = app.id);
    try {
      await _optimizationService.setStartupEnabled(app.id, enabled);
      final snapshot = await _optimizationService.fetchSnapshot();
      if (!mounted) return;
      setState(() => _optimization = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${app.name} will ${enabled ? 'start' : 'no longer start'} with your session.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update ${app.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _changingStartupId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetry;
    final scores = OptimizationHealthScores.calculate(
      cpuUsage: telemetry.cpuUsage,
      ramUsage: telemetry.ramUsage,
      cpuTemperature: telemetry.cpuTemp,
      gpuTemperature: telemetry.gpuTemp,
      cpuHistory: telemetry.cpuHistory,
      ramHistory: telemetry.ramHistory,
      cpuTemperatureHistory: telemetry.cpuTempHistory,
      gpuTemperatureHistory: telemetry.gpuTempHistory,
      optimization: _optimization,
      storage: _storage,
    );
    final averageRam = sampleAverage(
      telemetry.ramHistory,
      fallback: telemetry.ramUsage.toDouble(),
    );
    final peakRam = samplePeak(
      telemetry.ramHistory,
      fallback: telemetry.ramUsage.toDouble(),
    );
    final averageCpuTemp = _positiveAverage(
      telemetry.cpuTempHistory,
      telemetry.cpuTemp.toDouble(),
    );
    final peakCpuTemp = _positivePeak(
      telemetry.cpuTempHistory,
      telemetry.cpuTemp.toDouble(),
    );
    final recommendations = buildOptimizationRecommendations(
      OptimizationRecommendationContext(
        optimization: _optimization,
        storage: _storage,
        averageRam: averageRam,
        peakRam: peakRam,
        averageCpuTemperature: averageCpuTemp,
        peakCpuTemperature: peakCpuTemp,
      ),
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(loading: _loading, onRefresh: _refresh),
            const SizedBox(height: 20),
            if (_error != null)
              _ErrorBanner(message: _error!, onRetry: _refresh)
            else if (_loading && _optimization == null)
              const _LoadingHero()
            else
              _HealthHero(scores: scores),
            const SizedBox(height: 20),
            _RecommendationsPanel(
              recommendations: recommendations,
              onOpenProcesses: widget.onOpenProcesses,
              onOpenStorage: widget.onOpenStorage,
            ),
            const SizedBox(height: 20),
            _MaintenanceFactsCard(snapshot: _optimization),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 980;
                final startup = _StartupApplicationsCard(
                  snapshot: _optimization,
                  changingId: _changingStartupId,
                  onChanged: _setStartupEnabled,
                );
                final storage = _StorageAnalysisCard(
                  snapshot: _storage,
                  storageHistory: _storageHistory,
                  optimization: _optimization,
                  onOpenStorage: widget.onOpenStorage,
                );
                if (!twoColumns) {
                  return Column(
                    children: [startup, const SizedBox(height: 20), storage],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: startup),
                    const SizedBox(width: 20),
                    Expanded(child: storage),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 980;
                final memory = _MemoryInsightsCard(
                  current: telemetry.ramUsage.toDouble(),
                  average: averageRam,
                  peak: peakRam,
                  totalGb: telemetry.ramTotal,
                  history: telemetry.ramHistory,
                );
                final thermal = _ThermalInsightsCard(
                  averageCpu: averageCpuTemp,
                  peakCpu: peakCpuTemp,
                  averageGpu: _positiveAverage(
                    telemetry.gpuTempHistory,
                    telemetry.gpuTemp.toDouble(),
                  ),
                  peakGpu: _positivePeak(
                    telemetry.gpuTempHistory,
                    telemetry.gpuTemp.toDouble(),
                  ),
                  cpuHistory: telemetry.cpuTempHistory,
                  gpuHistory: telemetry.gpuTempHistory,
                );
                if (!twoColumns) {
                  return Column(
                    children: [memory, const SizedBox(height: 20), thermal],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: memory),
                    const SizedBox(width: 20),
                    Expanded(child: thermal),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _GamingModeCard(
              supported: _optimization?.gamingModeSupported ?? false,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceFactsCard extends StatelessWidget {
  final OptimizationSnapshot? snapshot;

  const _MaintenanceFactsCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final value = snapshot;
    final days = (value?.uptimeSeconds ?? 0) ~/ (24 * 60 * 60);
    final bios = [
      value?.biosVendor,
      value?.biosVersion,
      value?.biosDate,
    ].whereType<String>().join(' · ');
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      glowColor: Colors.tealAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maintenance evidence',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Read-only facts from this PC. Unavailable values are never guessed.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MaintenanceFact(
                icon: Icons.restart_alt_rounded,
                label: 'System uptime',
                value: value == null ? 'Loading…' : '$days days',
                detail: value?.restartRecommended == true
                    ? 'Restart recommended'
                    : 'Within the 14-day guidance',
              ),
              _MaintenanceFact(
                icon: Icons.developer_board_rounded,
                label: 'BIOS',
                value: bios.isEmpty ? 'Unavailable' : bios,
                detail: 'Firmware identity reported by the operating system',
              ),
              _MaintenanceFact(
                icon: Icons.battery_5_bar_rounded,
                label: 'Battery',
                value: value?.batteryPercent == null
                    ? 'Desktop or unavailable'
                    : '${value!.batteryPercent!.round()}%',
                detail: value?.batteryPluggedIn == null
                    ? 'No battery was reported'
                    : value!.batteryPluggedIn!
                    ? 'Connected to power'
                    : 'Running on battery',
              ),
              const _MaintenanceFact(
                icon: Icons.extension_rounded,
                label: 'Provider readiness',
                value: 'Extensible',
                detail:
                    'Driver, backup, and restore-point providers are isolated',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const _MaintenanceFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.tealAccent),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onRefresh;

  const _PageHeading({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Maintenance Centre',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Evidence-based upkeep, hardware health, and clear recommendations.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(loading ? 'Analysing' : 'Analyse now'),
        ),
      ],
    );
  }
}

class _HealthHero extends StatelessWidget {
  final OptimizationHealthScores scores;

  const _HealthHero({required this.scores});

  @override
  Widget build(BuildContext context) {
    final scoreItems = [
      ('Performance', scores.performance, Icons.speed_rounded, Colors.cyan),
      ('Startup', scores.startup, Icons.rocket_launch_rounded, Colors.purple),
      ('Storage', scores.storage, Icons.storage_rounded, Colors.blueAccent),
      ('Memory', scores.memory, Icons.memory_rounded, Colors.tealAccent),
      ('Thermal', scores.thermal, Icons.thermostat_rounded, Colors.orange),
    ];
    final healthColor = _scoreColor(scores.overall);

    return _PremiumCard(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  healthColor.withValues(alpha: 0.16),
                  AppColors.surface(context),
                  Colors.purple.withValues(alpha: 0.07),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 840;
                final overall = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreRing(
                      score: scores.overall,
                      size: compact ? 154 : 184,
                      strokeWidth: 13,
                      color: healthColor,
                      label: 'Overall health',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _healthLabel(scores.overall),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Live score from system workload, capacity, memory, startup, and thermals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
                final breakdown = Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final item in scoreItems)
                      _MiniScore(
                        label: item.$1,
                        score: item.$2,
                        icon: item.$3,
                        color: item.$4,
                      ),
                  ],
                );
                if (compact) {
                  return Column(
                    children: [overall, const SizedBox(height: 26), breakdown],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 260, child: overall),
                    Container(
                      width: 1,
                      height: 190,
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      color: AppColors.border(context),
                    ),
                    Expanded(child: breakdown),
                  ],
                );
              },
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.04, end: 0, duration: 500.ms);
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;
  final Color color;

  const _MiniScore({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        children: [
          _ScoreRing(
            score: score,
            size: 82,
            strokeWidth: 7,
            color: color,
            centerIcon: icon,
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$value / 100',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final double strokeWidth;
  final Color color;
  final String? label;
  final IconData? centerIcon;

  const _ScoreRing({
    required this.score,
    required this.size,
    required this.strokeWidth,
    required this.color,
    this.label,
    this.centerIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppColors.overlay(context, 0.06),
              ),
            ),
            Container(
              width: size * 0.62,
              height: size * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            if (centerIcon != null)
              Icon(centerIcon, color: color, size: size * 0.3)
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: TextStyle(
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                  if (label != null)
                    Text(
                      label!,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: size * 0.065,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationsPanel extends StatelessWidget {
  final List<OptimizationRecommendation> recommendations;
  final VoidCallback onOpenProcesses;
  final VoidCallback onOpenStorage;

  const _RecommendationsPanel({
    required this.recommendations,
    required this.onOpenProcesses,
    required this.onOpenStorage,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            color: Colors.amber,
            title: 'Recommendations',
            subtitle: recommendations.isEmpty
                ? 'No urgent actions found in the current analysis.'
                : '${recommendations.length} actionable ${recommendations.length == 1 ? 'insight' : 'insights'} from modular health engines.',
            trailing: _StatusPill(
              label: recommendations.isEmpty
                  ? 'All clear'
                  : '${recommendations.length} active',
              color: recommendations.isEmpty
                  ? Colors.greenAccent
                  : Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          if (recommendations.isEmpty)
            const _EmptyRecommendation()
          else
            for (var index = 0; index < recommendations.length; index++) ...[
              _RecommendationTile(
                recommendation: recommendations[index],
                onAction: recommendations[index].id == 'memory-pressure'
                    ? onOpenProcesses
                    : recommendations[index].id.startsWith('storage') ||
                          recommendations[index].id == 'temporary-files'
                    ? onOpenStorage
                    : null,
              ),
              if (index != recommendations.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final OptimizationRecommendation recommendation;
  final VoidCallback? onAction;

  const _RecommendationTile({required this.recommendation, this.onAction});

  @override
  Widget build(BuildContext context) {
    final color = switch (recommendation.severity) {
      OptimizationSeverity.info => Colors.cyan,
      OptimizationSeverity.warning => Colors.amber,
      OptimizationSeverity.critical => Colors.redAccent,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Material(
        color: color.withValues(alpha: 0.055),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
              ],
            ),
          ),
          title: Text(
            recommendation.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              recommendation.description,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(28, 0, 18, 16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    recommendation.details,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(width: 18),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(recommendation.action),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupApplicationsCard extends StatelessWidget {
  final OptimizationSnapshot? snapshot;
  final String? changingId;
  final Future<void> Function(StartupApplication app, bool enabled) onChanged;

  const _StartupApplicationsCard({
    required this.snapshot,
    required this.changingId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final apps = snapshot?.startupApps ?? const <StartupApplication>[];
    final enabledCount = apps.where((app) => app.enabled).length;
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.rocket_launch_rounded,
            color: Colors.purpleAccent,
            title: 'Startup applications',
            subtitle:
                '$enabledCount enabled · Estimated impact from application type',
            trailing: _StatusPill(
              label: snapshot?.startupToggleSupported == true
                  ? 'Controls ready'
                  : 'Read-only',
              color: snapshot?.startupToggleSupported == true
                  ? Colors.greenAccent
                  : Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          if (apps.isEmpty)
            _UnavailableMessage(
              icon: Icons.apps_rounded,
              title: 'No startup applications detected',
              message:
                  'HardwareMon will populate this list from Windows Run entries or Linux XDG autostart files.',
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: apps.length,
                separatorBuilder: (_, _) =>
                    Divider(color: AppColors.border(context), height: 1),
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final busy = changingId == app.id;
                  final impactColor = switch (app.impact) {
                    'high' => Colors.redAccent,
                    'low' => Colors.greenAccent,
                    _ => Colors.amber,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: impactColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.apps_rounded,
                            color: impactColor,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Tooltip(
                            message: '${app.command}\n\n${app.detail}',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  app.publisher,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusPill(
                          label: '${app.impact} impact',
                          color: impactColor,
                        ),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Tooltip(
                            message: app.canToggle
                                ? '${app.enabled ? 'Disable' : 'Enable'} ${app.name}'
                                : 'This platform entry is read-only',
                            child: Switch.adaptive(
                              value: app.enabled,
                              onChanged: app.canToggle
                                  ? (value) => onChanged(app, value)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageAnalysisCard extends StatelessWidget {
  final StorageSnapshot? snapshot;
  final StorageHistory? storageHistory;
  final OptimizationSnapshot? optimization;
  final VoidCallback onOpenStorage;

  const _StorageAnalysisCard({
    required this.snapshot,
    required this.storageHistory,
    required this.optimization,
    required this.onOpenStorage,
  });

  @override
  Widget build(BuildContext context) {
    final used = snapshot?.usedCapacity ?? 0;
    final free = snapshot?.freeCapacity ?? 0;
    final temp = optimization?.temporaryBytes ?? 0;
    final total = snapshot?.totalCapacity ?? 0;
    final usedRatio = total > 0 ? used / total : 0.0;
    final tempRatio = total > 0 ? temp / total : 0.0;
    final locations =
        optimization?.temporaryLocations ?? const <TemporaryFileLocation>[];

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.storage_rounded,
            color: Colors.blueAccent,
            title: 'Storage analysis',
            subtitle: snapshot == null
                ? 'Waiting for storage telemetry'
                : '${formatByteSize(free)} free across ${snapshot!.drives.length} ${snapshot!.drives.length == 1 ? 'drive' : 'drives'}',
            trailing: TextButton(
              onPressed: onOpenStorage,
              child: const Text('Open Storage'),
            ),
          ),
          const SizedBox(height: 18),
          _StorageBar(
            usedRatio: usedRatio,
            tempRatio: tempRatio,
            usedLabel: formatByteSize(used),
            freeLabel: formatByteSize(free),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InsightMetric(
                  label: 'Used',
                  value: snapshot == null
                      ? 'Unavailable'
                      : '${snapshot!.usedPercent.toStringAsFixed(0)}%',
                  icon: Icons.pie_chart_rounded,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'Temporary',
                  value: formatByteSize(temp),
                  icon: Icons.cleaning_services_rounded,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'Cleanup',
                  value: optimization?.cleanupSupported == true
                      ? 'Available'
                      : 'Review only',
                  icon: Icons.auto_delete_rounded,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Largest analysed locations',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (locations.isEmpty)
            const _UnavailableMessage(
              icon: Icons.folder_open_rounded,
              title: 'Directory analysis is preparing',
              message:
                  'Use the Storage page for a full drive scan and largest-file drilldown.',
            )
          else
            for (final location in locations.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Text(
                      formatByteSize(location.sizeBytes),
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          if ((storageHistory?.samples.length ?? 0) > 2) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 70,
              child: _TrendChart(
                series: [
                  _ChartSeries(
                    samples: storageHistory!.samples
                        .map(
                          (sample) => TelemetrySample(
                            timestamp: sample.timestamp,
                            value: sample.capacityPercent,
                          ),
                        )
                        .toList(growable: false),
                    color: Colors.blueAccent,
                  ),
                ],
                minY: 0,
                maxY: 100,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryInsightsCard extends StatelessWidget {
  final double current;
  final double average;
  final double peak;
  final double totalGb;
  final List<TelemetrySample> history;

  const _MemoryInsightsCard({
    required this.current,
    required this.average,
    required this.peak,
    required this.totalGb,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final pressure = peak >= 90
        ? 'Critical pressure'
        : average >= 80
        ? 'Sustained pressure'
        : current >= 70
        ? 'Elevated'
        : 'Comfortable';
    final color = peak >= 90
        ? Colors.redAccent
        : average >= 80
        ? Colors.orange
        : Colors.tealAccent;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.memory_rounded,
            color: Colors.tealAccent,
            title: 'Memory insights',
            subtitle: totalGb > 0
                ? '${totalGb.toStringAsFixed(1)} GB installed'
                : 'Historical and live memory pressure',
            trailing: _StatusPill(label: pressure, color: color),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InsightMetric(
                  label: 'Current',
                  value: '${current.toStringAsFixed(0)}%',
                  icon: Icons.bolt_rounded,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'Average',
                  value: '${average.toStringAsFixed(0)}%',
                  icon: Icons.equalizer_rounded,
                  color: Colors.tealAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'Peak',
                  value: '${peak.toStringAsFixed(0)}%',
                  icon: Icons.north_east_rounded,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 155,
            child: history.length < 2
                ? const _ChartWaiting(label: 'Memory trend is collecting')
                : _TrendChart(
                    series: [
                      _ChartSeries(samples: history, color: Colors.tealAccent),
                    ],
                    minY: 0,
                    maxY: 100,
                    threshold: 80,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThermalInsightsCard extends StatelessWidget {
  final double averageCpu;
  final double peakCpu;
  final double averageGpu;
  final double peakGpu;
  final List<TelemetrySample> cpuHistory;
  final List<TelemetrySample> gpuHistory;

  const _ThermalInsightsCard({
    required this.averageCpu,
    required this.peakCpu,
    required this.averageGpu,
    required this.peakGpu,
    required this.cpuHistory,
    required this.gpuHistory,
  });

  @override
  Widget build(BuildContext context) {
    final events =
        cpuHistory.where((sample) => sample.value >= 85).length +
        gpuHistory.where((sample) => sample.value >= 88).length;
    final available = averageCpu > 0 || averageGpu > 0;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.thermostat_rounded,
            color: Colors.orange,
            title: 'Thermal insights',
            subtitle: available
                ? 'CPU and GPU temperature history'
                : 'Temperature sensors are unavailable',
            trailing: _StatusPill(
              label: available
                  ? events == 0
                        ? 'No hot events'
                        : '$events hot ${events == 1 ? 'event' : 'events'}'
                  : 'Unavailable',
              color: !available
                  ? Colors.grey
                  : events == 0
                  ? Colors.greenAccent
                  : Colors.orange,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InsightMetric(
                  label: 'CPU average',
                  value: _temperature(averageCpu),
                  icon: Icons.memory_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'CPU peak',
                  value: _temperature(peakCpu),
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetric(
                  label: 'GPU average',
                  value: _temperature(averageGpu),
                  icon: Icons.developer_board_rounded,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 155,
            child:
                !available || (cpuHistory.length < 2 && gpuHistory.length < 2)
                ? const _ChartWaiting(
                    label: 'Thermal history will appear when sensors report',
                  )
                : _TrendChart(
                    series: [
                      _ChartSeries(samples: cpuHistory, color: Colors.orange),
                      _ChartSeries(
                        samples: gpuHistory,
                        color: Colors.purpleAccent,
                      ),
                    ],
                    minY: 20,
                    maxY: 105,
                    threshold: 85,
                  ),
          ),
        ],
      ),
    );
  }
}

class _GamingModeCard extends StatefulWidget {
  final bool supported;

  const _GamingModeCard({required this.supported});

  @override
  State<_GamingModeCard> createState() => _GamingModeCardState();
}

class _GamingModeCardState extends State<_GamingModeCard> {
  final Set<String> _selected = {
    'Close background apps',
    'Enable performance profile',
    'Reduce distractions',
    'Optimise for gaming',
  };

  @override
  Widget build(BuildContext context) {
    const options = [
      ('Close background apps', Icons.layers_clear_rounded),
      ('Enable performance profile', Icons.speed_rounded),
      ('Reduce distractions', Icons.notifications_off_rounded),
      ('Optimise for gaming', Icons.sports_esports_rounded),
    ];
    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              Colors.purple.withValues(alpha: 0.14),
              AppColors.surface(context),
              Colors.cyan.withValues(alpha: 0.07),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: Colors.purpleAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gaming Mode',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Performance orchestration architecture',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      label: widget.supported ? 'Ready' : 'Preview',
                      color: widget.supported
                          ? Colors.greenAccent
                          : Colors.purpleAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.supported
                      ? 'Prepare the desktop for a focused gaming session.'
                      : 'The production UI and configuration model are ready. OS-level game optimisation will arrive in a future release.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            );
            final controls = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  FilterChip(
                    avatar: Icon(option.$2, size: 16),
                    label: Text(option.$1),
                    selected: _selected.contains(option.$1),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(option.$1);
                        } else {
                          _selected.remove(option.$1);
                        }
                      });
                    },
                  ),
              ],
            );
            final action = FilledButton.icon(
              onPressed: widget.supported
                  ? () {}
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Gaming Mode is prepared but OS-level actions are not enabled in this release.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                widget.supported ? 'Activate Gaming Mode' : 'Preview setup',
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  intro,
                  const SizedBox(height: 18),
                  controls,
                  const SizedBox(height: 18),
                  action,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 4, child: intro),
                const SizedBox(width: 28),
                Expanded(flex: 5, child: controls),
                const SizedBox(width: 22),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PremiumCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<_PremiumCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _hovering
                ? AppColors.accent.withValues(alpha: 0.35)
                : AppColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : AppColors.shadow(context),
              blurRadius: _hovering ? 30 : 16,
              spreadRadius: _hovering ? 1 : 0,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  final double usedRatio;
  final double tempRatio;
  final String usedLabel;
  final String freeLabel;

  const _StorageBar({
    required this.usedRatio,
    required this.tempRatio,
    required this.usedLabel,
    required this.freeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 15,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(color: AppColors.overlay(context, 0.06)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      width: width * usedRatio.clamp(0, 1),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.cyan],
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * (usedRatio - tempRatio).clamp(0.0, 1.0),
                      child: Container(
                        width: width * tempRatio.clamp(0, 1),
                        height: 15,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$usedLabel used',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '$freeLabel free',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartSeries {
  final List<TelemetrySample> samples;
  final Color color;

  const _ChartSeries({required this.samples, required this.color});
}

class _TrendChart extends StatelessWidget {
  final List<_ChartSeries> series;
  final double minY;
  final double maxY;
  final double? threshold;

  const _TrendChart({
    required this.series,
    required this.minY,
    required this.maxY,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final usable = series.where((item) => item.samples.isNotEmpty).toList();
    if (usable.isEmpty) return const SizedBox.shrink();
    final lines = <LineChartBarData>[];
    for (final item in usable) {
      lines.add(
        LineChartBarData(
          spots: [
            for (var index = 0; index < item.samples.length; index++)
              FlSpot(index.toDouble(), item.samples[index].value),
          ],
          isCurved: true,
          curveSmoothness: 0.25,
          barWidth: 2,
          color: item.color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                item.color.withValues(alpha: 0.18),
                item.color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );
    }
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: lines,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border(context), strokeWidth: 1),
        ),
        extraLinesData: threshold == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: threshold!,
                    color: Colors.orange.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ],
              ),
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _UnavailableMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    height: 1.4,
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

class _EmptyRecommendation extends StatelessWidget {
  const _EmptyRecommendation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.12)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Colors.greenAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'The current sample is healthy. HardwareMon will keep watching for sustained pressure, thermal events, startup impact, and storage risk.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimisation analysis is temporarily unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return const _PremiumCard(
      child: SizedBox(
        height: 190,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Building your system health profile…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartWaiting extends StatelessWidget {
  final String label;

  const _ChartWaiting({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(color: AppColors.textMuted(context), fontSize: 11),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 85) return Colors.greenAccent;
  if (score >= 65) return Colors.cyan;
  if (score >= 45) return Colors.orange;
  return Colors.redAccent;
}

String _healthLabel(int score) {
  if (score >= 90) return 'Excellent';
  if (score >= 75) return 'Healthy';
  if (score >= 60) return 'Good, with opportunities';
  if (score >= 40) return 'Attention recommended';
  return 'Action recommended';
}

double _positiveAverage(List<TelemetrySample> samples, double fallback) {
  final values = samples
      .map((sample) => sample.value)
      .where((value) => value > 0)
      .toList();
  if (values.isEmpty) return fallback;
  return values.reduce((left, right) => left + right) / values.length;
}

double _positivePeak(List<TelemetrySample> samples, double fallback) {
  return samples
      .map((sample) => sample.value)
      .where((value) => value > 0)
      .fold<double>(fallback, math.max);
}

String _temperature(double value) {
  return value > 0 ? '${value.toStringAsFixed(0)}°C' : 'Unavailable';
}
