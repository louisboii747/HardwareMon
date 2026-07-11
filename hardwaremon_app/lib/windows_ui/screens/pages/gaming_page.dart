import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../services/alert_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/gaming_models.dart';
import '../../services/gaming_service.dart';
import '../../widgets/glass_panel.dart';

enum _GamingTab { live, history, statistics }

class GamingPage extends StatefulWidget {
  final GamingService? service;

  const GamingPage({super.key, this.service});

  @override
  State<GamingPage> createState() => _GamingPageState();
}

class _GamingPageState extends State<GamingPage> {
  late final GamingService _service;
  GamingCurrent _current = const GamingCurrent(
    active: false,
    session: null,
    lastEvent: null,
    knownGames: 0,
    pollIntervalSeconds: 5,
  );
  GamingSession? _latest;
  List<GamingSession> _history = const [];
  GamingStatistics _statistics = const GamingStatistics.empty();
  Timer? _pollTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  _GamingTab _tab = _GamingTab.live;
  final Set<String> _seenEvents = <String>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GamingService();
    _load(initial: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshCurrent(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final values = await Future.wait<dynamic>([
        _service.fetchCurrent(),
        _service.fetchHistory(limit: 100),
        _service.fetchStatistics(),
        _service.fetchLatest(),
      ]);
      if (!mounted) return;
      final current = values[0] as GamingCurrent;
      setState(() {
        _current = current;
        _history = values[1] as List<GamingSession>;
        _statistics = values[2] as GamingStatistics;
        _latest = values[3] as GamingSession?;
        _loading = false;
        _error = null;
      });
      _handleEvent(current.lastEvent, initial: initial);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _refreshCurrent() async {
    if (_refreshing) return;
    _refreshing = true;
    final wasActive = _current.active;
    try {
      final current = await _service.fetchCurrent();
      if (!mounted) return;
      setState(() {
        _current = current;
        _error = null;
      });
      _handleEvent(current.lastEvent);
      if (wasActive && !current.active) {
        await _refreshHistory();
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshHistory() async {
    try {
      final values = await Future.wait<dynamic>([
        _service.fetchHistory(limit: 100),
        _service.fetchStatistics(),
        _service.fetchLatest(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = values[0] as List<GamingSession>;
        _statistics = values[1] as GamingStatistics;
        _latest = values[2] as GamingSession?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _deleteSession(GamingSession session) async {
    try {
      await _service.deleteSession(session.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${session.gameName} session deleted')),
      );
      await _refreshHistory();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  void _handleEvent(GamingEvent? event, {bool initial = false}) {
    if (event == null || event.id.isEmpty) return;
    if (initial) {
      _seenEvents.add(event.id);
      return;
    }
    if (!_seenEvents.add(event.id)) return;

    unawaited(
      AlertService.instance.showDesktopNotification(
        identifier: event.id,
        title: event.title,
        body: event.body,
        silent: true,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.title} · ${event.gameName}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst(
      RegExp(r'^(Exception|Bad state):\s*'),
      '',
    );
    if (message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('socket')) {
      return 'Gaming Mode is waiting for the HardwareMon backend.';
    }
    return message.isEmpty
        ? 'Gaming Mode is temporarily unavailable.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('gaming-page-scroll'),
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _ErrorBanner(message: _error!, onRetry: () => _load()),
            const SizedBox(height: 14),
          ],
          _buildTabs(),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              height: 360,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            switch (_tab) {
              _GamingTab.live => _buildLive(),
              _GamingTab.history => _buildHistory(),
              _GamingTab.statistics => _buildStatistics(),
            },
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.deepOrangeAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.sports_esports_rounded,
            color: Colors.deepOrangeAccent,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gaming',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                'Automatic session capture · ${_current.knownGames} known games',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        _StatusPill(active: _current.active),
      ],
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_GamingTab>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _GamingTab.live,
            icon: Icon(Icons.radio_button_checked_rounded, size: 16),
            label: Text('Live'),
          ),
          ButtonSegment(
            value: _GamingTab.history,
            icon: Icon(Icons.history_rounded, size: 16),
            label: Text('History'),
          ),
          ButtonSegment(
            value: _GamingTab.statistics,
            icon: Icon(Icons.query_stats_rounded, size: 16),
            label: Text('Statistics'),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (selection) {
          setState(() => _tab = selection.first);
        },
      ),
    );
  }

  Widget _buildLive() {
    final session = _current.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentGamePanel(
          current: _current,
          latest: _latest,
          onOpenLatest: _latest == null ? null : () => _showSession(_latest!),
        ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.025),
        const SizedBox(height: 16),
        if (session != null)
          _MetricGrid(metrics: _liveMetrics(session))
        else
          _MetricGrid(metrics: _idleMetrics()),
      ],
    );
  }

  List<_GamingMetric> _liveMetrics(GamingSession session) {
    final sample = session.latestSample;
    return [
      _GamingMetric(
        label: 'CPU',
        value: _percent(sample?.cpuUsage ?? session.avgCpuUsage),
        subtitle: 'Average ${_percent(session.avgCpuUsage)}',
        icon: Icons.memory_rounded,
        color: AppColors.accent,
        progress: _progress(sample?.cpuUsage ?? session.avgCpuUsage),
      ),
      _GamingMetric(
        label: 'GPU',
        value: _percent(sample?.gpuUsage ?? session.avgGpuUsage),
        subtitle: 'Peak ${_percent(session.peakGpuUsage)}',
        icon: Icons.developer_board_rounded,
        color: Colors.purpleAccent,
        progress: _progress(sample?.gpuUsage ?? session.avgGpuUsage),
      ),
      _GamingMetric(
        label: 'Memory',
        value: _percent(sample?.ramUsage ?? session.avgRamUsage),
        subtitle: 'Peak ${_percent(session.peakRamUsage)}',
        icon: Icons.view_in_ar_rounded,
        color: Colors.lightGreenAccent,
        progress: _progress(sample?.ramUsage ?? session.avgRamUsage),
      ),
      _GamingMetric(
        label: 'CPU Temp',
        value: _temperature(
          sample?.cpuTemperature ?? session.avgCpuTemperature,
        ),
        subtitle: 'Peak ${_temperature(session.peakCpuTemperature)}',
        icon: Icons.thermostat_rounded,
        color: Colors.orangeAccent,
        progress: _thermalProgress(
          sample?.cpuTemperature ?? session.peakCpuTemperature,
        ),
      ),
      _GamingMetric(
        label: 'GPU Temp',
        value: _temperature(
          sample?.gpuTemperature ?? session.avgGpuTemperature,
        ),
        subtitle: 'Peak ${_temperature(session.peakGpuTemperature)}',
        icon: Icons.device_thermostat_rounded,
        color: Colors.redAccent,
        progress: _thermalProgress(
          sample?.gpuTemperature ?? session.peakGpuTemperature,
        ),
      ),
      _GamingMetric(
        label: 'Power',
        value: _watts(sample?.gpuPower ?? session.avgGpuPower),
        subtitle: 'CPU ${_watts(sample?.cpuPower ?? session.avgCpuPower)}',
        icon: Icons.electric_bolt_rounded,
        color: Colors.amberAccent,
        progress: null,
      ),
      _GamingMetric(
        label: 'CPU Clock',
        value: _clock(session.avgCpuClock),
        subtitle: '${session.totalSamples} samples collected',
        icon: Icons.av_timer_rounded,
        color: Colors.lightBlueAccent,
        progress: null,
      ),
    ];
  }

  List<_GamingMetric> _idleMetrics() {
    return [
      _GamingMetric(
        label: 'Detector',
        value: 'Ready',
        subtitle:
            'Scanning every ${_current.pollIntervalSeconds.toStringAsFixed(0)}s',
        icon: Icons.radar_rounded,
        color: Colors.greenAccent,
        progress: null,
      ),
      _GamingMetric(
        label: 'Catalog',
        value: '${_current.knownGames}',
        subtitle: 'Known executables',
        icon: Icons.storage_rounded,
        color: AppColors.accent,
        progress: null,
      ),
      _GamingMetric(
        label: 'Sessions',
        value: '${_statistics.totalSessions}',
        subtitle: '${_durationLabel(_statistics.totalGamingSeconds)} total',
        icon: Icons.history_rounded,
        color: Colors.purpleAccent,
        progress: null,
      ),
    ];
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'No gaming sessions yet',
        message:
            'Launch a known game and HardwareMon will record the session automatically.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _history.length; index++) ...[
          _SessionCard(
            session: _history[index],
            onTap: () => _showSession(_history[index]),
          ).animate(delay: (45 * index).ms).fadeIn().slideY(begin: 0.02),
          if (index != _history.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildStatistics() {
    final stats = _statistics;
    final cards = [
      _GamingMetric(
        label: 'Most Played',
        value: stats.mostPlayedGame?.gameName ?? 'None',
        subtitle: stats.mostPlayedGame == null
            ? 'No completed sessions'
            : _durationLabel(stats.mostPlayedGame!.durationSeconds),
        icon: Icons.emoji_events_rounded,
        color: Colors.amberAccent,
      ),
      _GamingMetric(
        label: 'Longest',
        value: stats.longestSession?.gameName ?? 'None',
        subtitle: stats.longestSession == null
            ? 'No completed sessions'
            : _durationLabel(stats.longestSession!.durationSeconds),
        icon: Icons.timer_rounded,
        color: AppColors.accent,
      ),
      _GamingMetric(
        label: 'Total Hours',
        value: stats.totalGamingHours.toStringAsFixed(1),
        subtitle: '${stats.totalSessions} sessions',
        icon: Icons.schedule_rounded,
        color: Colors.purpleAccent,
      ),
      _GamingMetric(
        label: 'Average Length',
        value: _durationLabel(stats.averageSessionSeconds),
        subtitle: '${stats.gamesPlayed} games played',
        icon: Icons.balance_rounded,
        color: Colors.lightBlueAccent,
      ),
      _GamingMetric(
        label: 'Hottest',
        value: stats.hottestRecordedSession?.gameName ?? 'None',
        subtitle: stats.hottestRecordedSession == null
            ? 'No thermal samples'
            : 'CPU ${_temperature(stats.hottestRecordedSession!.peakCpuTemperature)} · GPU ${_temperature(stats.hottestRecordedSession!.peakGpuTemperature)}',
        icon: Icons.local_fire_department_rounded,
        color: Colors.deepOrangeAccent,
      ),
      _GamingMetric(
        label: 'Avg CPU Temp',
        value: _temperature(stats.averageCpuTemperature),
        subtitle: 'Across completed sessions',
        icon: Icons.thermostat_rounded,
        color: Colors.orangeAccent,
      ),
      _GamingMetric(
        label: 'Avg GPU Temp',
        value: _temperature(stats.averageGpuTemperature),
        subtitle: 'Across completed sessions',
        icon: Icons.device_thermostat_rounded,
        color: Colors.redAccent,
      ),
      _GamingMetric(
        label: 'Largest GPU',
        value: _percent(stats.largestGpuUsage),
        subtitle: 'Peak session usage',
        icon: Icons.developer_board_rounded,
        color: Colors.purpleAccent,
        progress: _progress(stats.largestGpuUsage),
      ),
      _GamingMetric(
        label: 'Largest CPU',
        value: _percent(stats.largestCpuUsage),
        subtitle: 'Peak session usage',
        icon: Icons.memory_rounded,
        color: AppColors.accent,
        progress: _progress(stats.largestCpuUsage),
      ),
      _GamingMetric(
        label: 'Games Played',
        value: '${stats.gamesPlayed}',
        subtitle: '${stats.knownGames} known games',
        icon: Icons.apps_rounded,
        color: Colors.lightGreenAccent,
      ),
    ];

    return _MetricGrid(metrics: cards);
  }

  Future<void> _showSession(GamingSession session) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sports_esports_rounded, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(session.gameName)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${DateFormat.yMMMd().add_jm().format(session.startedAt)} · ${_durationLabel(session.durationSeconds)}',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _DetailMetric(
                      label: 'Executable',
                      value: session.executable,
                    ),
                    _DetailMetric(
                      label: 'Average CPU',
                      value: _percent(session.avgCpuUsage),
                    ),
                    _DetailMetric(
                      label: 'Average GPU',
                      value: _percent(session.avgGpuUsage),
                    ),
                    _DetailMetric(
                      label: 'Average RAM',
                      value: _percent(session.avgRamUsage),
                    ),
                    _DetailMetric(
                      label: 'Peak CPU Temp',
                      value: _temperature(session.peakCpuTemperature),
                    ),
                    _DetailMetric(
                      label: 'Peak GPU Temp',
                      value: _temperature(session.peakGpuTemperature),
                    ),
                    _DetailMetric(
                      label: 'CPU Power',
                      value: _watts(session.avgCpuPower),
                    ),
                    _DetailMetric(
                      label: 'GPU Power',
                      value: _watts(session.avgGpuPower),
                    ),
                    _DetailMetric(
                      label: 'CPU Clock',
                      value: _clock(session.avgCpuClock),
                    ),
                    _DetailMetric(
                      label: 'Samples',
                      value: '${session.totalSamples}',
                    ),
                    _DetailMetric(
                      label: 'Version',
                      value: session.hardwaremonVersion,
                    ),
                    _DetailMetric(label: 'Platform', value: session.platform),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!session.isActive)
            TextButton.icon(
              onPressed: () => _deleteSession(session),
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _CurrentGamePanel extends StatelessWidget {
  final GamingCurrent current;
  final GamingSession? latest;
  final VoidCallback? onOpenLatest;

  const _CurrentGamePanel({
    required this.current,
    required this.latest,
    required this.onOpenLatest,
  });

  @override
  Widget build(BuildContext context) {
    final session = current.session;
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      glowColor: current.active ? Colors.deepOrangeAccent : AppColors.accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final artwork = _ArtworkPlaceholder(
            title: session?.gameName ?? latest?.gameName ?? 'Gaming',
            active: current.active,
          );
          final details = session == null
              ? _IdleCurrentGame(latest: latest, onOpenLatest: onOpenLatest)
              : _ActiveCurrentGame(session: session);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [artwork, const SizedBox(height: 18), details],
            );
          }
          return Row(
            children: [
              SizedBox(width: 190, child: artwork),
              const SizedBox(width: 22),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  final String title;
  final bool active;

  const _ArtworkPlaceholder({required this.title, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.deepOrangeAccent : AppColors.accent;
    final initials = title
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.34),
              Colors.purpleAccent.withValues(alpha: 0.18),
              AppColors.overlay(context, 0.06),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                initials.isEmpty ? 'HM' : initials,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Icon(Icons.image_outlined, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Artwork placeholder',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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

class _ActiveCurrentGame extends StatelessWidget {
  final GamingSession session;

  const _ActiveCurrentGame({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LivePill(),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                session.executable,
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
        const SizedBox(height: 12),
        Text(
          session.gameName,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Running for ${_durationLabel(session.durationSeconds)} · ${session.totalSamples} samples',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _InlineMetric(
              label: 'CPU',
              value: _percent(
                session.latestSample?.cpuUsage ?? session.avgCpuUsage,
              ),
            ),
            _InlineMetric(
              label: 'GPU',
              value: _percent(
                session.latestSample?.gpuUsage ?? session.avgGpuUsage,
              ),
            ),
            _InlineMetric(
              label: 'Memory',
              value: _percent(
                session.latestSample?.ramUsage ?? session.avgRamUsage,
              ),
            ),
            _InlineMetric(
              label: 'CPU Temp',
              value: _temperature(
                session.latestSample?.cpuTemperature ??
                    session.avgCpuTemperature,
              ),
            ),
            _InlineMetric(
              label: 'GPU Temp',
              value: _temperature(
                session.latestSample?.gpuTemperature ??
                    session.avgGpuTemperature,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IdleCurrentGame extends StatelessWidget {
  final GamingSession? latest;
  final VoidCallback? onOpenLatest;

  const _IdleCurrentGame({required this.latest, required this.onOpenLatest});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting for a known game',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'HardwareMon will start and finish sessions automatically while the backend is running.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            height: 1.45,
          ),
        ),
        if (latest != null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InlineMetric(label: 'Latest', value: latest!.gameName),
              _InlineMetric(
                label: 'Duration',
                value: _durationLabel(latest!.durationSeconds),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLatest,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View latest'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_GamingMetric> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < metrics.length; index++)
              SizedBox(
                width: width,
                child: _GamingMetricCard(
                  metric: metrics[index],
                ).animate(delay: (45 * index).ms).fadeIn().scaleXY(begin: 0.98),
              ),
          ],
        );
      },
    );
  }
}

class _GamingMetricCard extends StatelessWidget {
  final _GamingMetric metric;

  const _GamingMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      glowColor: metric.color,
      child: SizedBox(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 18),
                ),
                const Spacer(),
                if (metric.progress != null)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      value: metric.progress,
                      strokeWidth: 3,
                      backgroundColor: AppColors.overlay(context, 0.05),
                      valueColor: AlwaysStoppedAnimation(metric.color),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.subtitle,
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

class _SessionCard extends StatelessWidget {
  final GamingSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        glowColor: Colors.deepOrangeAccent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final title = Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.deepOrangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: Colors.deepOrangeAccent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.gameName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat.yMMMd().add_jm().format(session.startedAt),
                        style: TextStyle(
                          color: AppColors.textMuted(context),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final metrics = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InlineMetric(
                  label: 'Duration',
                  value: _durationLabel(session.durationSeconds),
                ),
                _InlineMetric(
                  label: 'CPU',
                  value: _percent(session.avgCpuUsage),
                ),
                _InlineMetric(
                  label: 'GPU',
                  value: _percent(session.avgGpuUsage),
                ),
                _InlineMetric(
                  label: 'Peak CPU',
                  value: _temperature(session.peakCpuTemperature),
                ),
                _InlineMetric(
                  label: 'Peak GPU',
                  value: _temperature(session.peakGpuTemperature),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 13), metrics],
              );
            }
            return Row(
              children: [
                Expanded(flex: 4, child: title),
                const SizedBox(width: 18),
                Expanded(flex: 6, child: metrics),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;

  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.deepOrangeAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        active ? 'RECORDING' : 'READY',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepOrangeAccent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.deepOrangeAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.deepOrangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'LIVE SESSION',
            style: TextStyle(
              color: Colors.deepOrangeAccent,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accent, size: 36),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.orange),
          const SizedBox(width: 11),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _GamingMetric {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? progress;

  const _GamingMetric({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
  });
}

String _percent(double? value) {
  if (value == null) return 'Unavailable';
  return '${value.round()}%';
}

String _temperature(double? value) {
  if (value == null || value <= 0) return 'Unavailable';
  return '${value.round()}°C';
}

String _watts(double? value) {
  if (value == null || value <= 0) return 'Unavailable';
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} W';
}

String _clock(double? mhz) {
  if (mhz == null || mhz <= 0) return 'Unavailable';
  if (mhz >= 1000) return '${(mhz / 1000).toStringAsFixed(2)} GHz';
  return '${mhz.toStringAsFixed(0)} MHz';
}

double? _progress(double? value) {
  if (value == null) return null;
  return (value / 100).clamp(0, 1).toDouble();
}

double? _thermalProgress(double? value) {
  if (value == null || value <= 0) return null;
  return (value / 100).clamp(0, 1).toDouble();
}

String _durationLabel(double seconds) {
  final total = math.max(0, seconds.round());
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${secs}s';
  return '${secs}s';
}
