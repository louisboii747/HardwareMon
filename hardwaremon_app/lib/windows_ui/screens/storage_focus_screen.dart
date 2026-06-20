import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../models/storage_models.dart';
import '../services/storage_service.dart';
import '../widgets/glass_panel.dart';
import '../widgets/storage_visuals.dart';

enum StorageFocusAction { overview, scan, benchmark }

enum _FocusRange {
  minute('Last minute', 60),
  hour('Last hour', 3600),
  session('Session', 21600),
  day('24 hours', 86400),
  week('7 days', 604800),
  month('30 days', 2592000);

  final String label;
  final int seconds;

  const _FocusRange(this.label, this.seconds);
}

class StorageFocusScreen extends StatefulWidget {
  final StorageDrive initialDrive;
  final StorageFocusAction initialAction;

  const StorageFocusScreen({
    super.key,
    required this.initialDrive,
    this.initialAction = StorageFocusAction.overview,
  });

  @override
  State<StorageFocusScreen> createState() => _StorageFocusScreenState();
}

class _StorageFocusScreenState extends State<StorageFocusScreen> {
  final StorageService _service = StorageService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scannerKey = GlobalKey();
  final GlobalKey _benchmarkKey = GlobalKey();
  Timer? _timer;
  late StorageDrive _drive;
  StorageHistory? _history;
  _FocusRange _range = _FocusRange.hour;
  bool _refreshing = false;
  bool _historyLoading = true;
  StorageScanJob? _scanJob;
  StorageBenchmarkJob? _benchmarkJob;
  bool _sortFilesBySize = true;

  @override
  void initState() {
    super.initState();
    _drive = widget.initialDrive;
    unawaited(_loadHistory());
    unawaited(_refreshDrive());
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshDrive(silent: true)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.initialAction) {
        case StorageFocusAction.scan:
          _scrollTo(_scannerKey);
          unawaited(_startScan());
        case StorageFocusAction.benchmark:
          _scrollTo(_benchmarkKey);
        case StorageFocusAction.overview:
          break;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshDrive({bool silent = false}) async {
    if (!silent && mounted) setState(() => _refreshing = true);
    try {
      final snapshot = await _service.fetchSnapshot();
      final updated = snapshot.drives.cast<StorageDrive?>().firstWhere(
        (drive) => drive?.id == widget.initialDrive.id,
        orElse: () => null,
      );
      if (!mounted || updated == null) return;
      setState(() {
        _drive = updated;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      if (!silent) _toast('Refresh failed: $error', error: true);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final history = await _service.fetchHistory(
        driveId: _drive.id,
        rangeSeconds: _range.seconds,
        points: _range == _FocusRange.month ? 720 : 480,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
      _toast('Historical analytics unavailable: $error', error: true);
    }
  }

  Future<void> _selectRange(_FocusRange range) async {
    if (_range == range) return;
    setState(() => _range = range);
    await _loadHistory();
  }

  Future<void> _startScan() async {
    if (_scanJob?.status == 'running') return;
    try {
      final jobId = await _service.startScan(_drive.id);
      if (!mounted) return;
      setState(() {
        _scanJob = StorageScanJob(
          id: jobId,
          status: 'running',
          progress: 0,
          scannedBytes: 0,
          scannedFiles: 0,
          currentPath: _drive.mountPoint,
          error: null,
          tree: const [],
          largestFiles: const [],
        );
      });
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final job = await _service.fetchScan(jobId);
        if (!mounted || _scanJob?.id != jobId) return;
        setState(() => _scanJob = job);
        if (job.isFinished) {
          _toast(
            job.status == 'complete'
                ? 'Usage scan complete'
                : job.error ?? 'Usage scan failed',
            error: job.status == 'failed',
          );
          return;
        }
      }
    } catch (error) {
      _toast('Could not start scan: $error', error: true);
    }
  }

  Future<void> _startBenchmark(String mode) async {
    if (_benchmarkJob?.status == 'running') return;
    try {
      final jobId = await _service.startBenchmark(_drive.id, mode);
      if (!mounted) return;
      setState(() {
        _benchmarkJob = StorageBenchmarkJob(
          id: jobId,
          status: 'running',
          mode: mode,
          progress: 0,
          error: null,
          results: null,
        );
      });
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final job = await _service.fetchBenchmark(jobId);
        if (!mounted || _benchmarkJob?.id != jobId) return;
        setState(() => _benchmarkJob = job);
        if (job.isFinished) {
          _toast(
            job.status == 'complete'
                ? '${mode == 'quick' ? 'Quick' : 'Full'} benchmark complete'
                : job.error ?? 'Benchmark failed',
            error: job.status == 'failed',
          );
          return;
        }
      }
    } catch (error) {
      _toast('Could not run benchmark: $error', error: true);
    }
  }

  Future<void> _openDrive() async {
    try {
      await _service.openDrive(_drive.id);
    } catch (error) {
      _toast('Could not open drive: $error', error: true);
    }
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: _drive.mountPoint));
    _toast('${_drive.mountPoint} copied');
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline_rounded : Icons.check_rounded,
                color: error ? Colors.redAccent : Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final color = storageHealthColor(_drive.health);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background(context),
                  Color.lerp(
                    AppColors.backgroundSecondary(context),
                    color,
                    0.045,
                  )!,
                  AppColors.backgroundTertiary(context),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 42),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHero(),
                          const SizedBox(height: 20),
                          _buildPrimaryAnalytics(),
                          const SizedBox(height: 20),
                          _buildActivityAnalytics(),
                          const SizedBox(height: 20),
                          _buildHealthAndForecast(),
                          const SizedBox(height: 20),
                          _buildScanner(),
                          const SizedBox(height: 20),
                          _buildBenchmark(),
                        ],
                      ),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Storage',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          Text(
            'DRIVE FOCUS',
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          _FocusAction(
            icon: Icons.folder_open_rounded,
            label: 'Open Drive',
            onPressed: _openDrive,
          ),
          _FocusAction(
            icon: Icons.content_copy_rounded,
            label: 'Copy Path',
            onPressed: _copyPath,
          ),
          _FocusAction(
            icon: Icons.manage_search_rounded,
            label: 'Scan Usage',
            onPressed: () async {
              _scrollTo(_scannerKey);
              await _startScan();
            },
          ),
          _FocusAction(
            icon: Icons.speed_rounded,
            label: 'Benchmark',
            onPressed: () async => _scrollTo(_benchmarkKey),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refreshDrive,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final color = storageHealthColor(_drive.health);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.075),
              AppColors.surface(context),
            ],
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 42),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        _drive.removable
                            ? Icons.usb_rounded
                            : Icons.storage_rounded,
                        color: color,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _drive.displayName,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_drive.mountPoint} · ${_drive.model}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StorageHealthBadge(health: _drive.health),
                    _AttributePill(
                      icon: Icons.score_rounded,
                      label: 'Score ${_drive.score}/100',
                      color: color,
                    ),
                    _AttributePill(
                      icon: Icons.memory_rounded,
                      label: _drive.interfaceType,
                    ),
                    _AttributePill(
                      icon: Icons.folder_copy_outlined,
                      label: _drive.filesystem,
                    ),
                  ],
                ),
              ],
            );
            final score = StorageCapacityRing(
              percent: _drive.usedPercent,
              color: color,
              size: 138,
              strokeWidth: 12,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: _drive.usedPercent),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '${value.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  Text(
                    'CAPACITY USED',
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            );
            if (compact) {
              return Column(
                children: [identity, const SizedBox(height: 20), score],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 24),
                score,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrimaryAnalytics() {
    final stats = [
      _MiniStat(
        label: 'Total',
        value: formatStorageBytes(_drive.totalBytes),
        icon: Icons.dns_outlined,
      ),
      _MiniStat(
        label: 'Used',
        value: formatStorageBytes(_drive.usedBytes),
        icon: Icons.pie_chart_outline_rounded,
        color: Colors.cyanAccent,
      ),
      _MiniStat(
        label: 'Free',
        value: formatStorageBytes(_drive.freeBytes),
        icon: Icons.circle_outlined,
        color: Colors.greenAccent,
      ),
      _MiniStat(
        label: 'Temperature',
        value: _drive.temperatureC == null
            ? 'Unavailable'
            : '${_drive.temperatureC!.toStringAsFixed(0)}°C',
        icon: Icons.device_thermostat_rounded,
        color: storageHealthColor(_drive.health),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FocusSectionHeader(
                eyebrow: 'CAPACITY ANALYTICS',
                title: 'Used vs Free',
                detail: 'Historical capacity movement',
                icon: Icons.donut_large_rounded,
              ),
              const SizedBox(height: 16),
              _historyLoading
                  ? const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _CapacityHistoryChart(
                      samples: _history?.samples ?? const [],
                    ),
            ],
          ),
        );
        final breakdown = GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FocusSectionHeader(
                eyebrow: 'BREAKDOWN',
                title: 'Capacity Composition',
                detail: 'Current allocation across this volume',
                icon: Icons.data_usage_rounded,
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < stats.length; index++) ...[
                _MiniStatRow(stat: stats[index]),
                if (index != stats.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
        if (constraints.maxWidth < 850) {
          return Column(
            children: [breakdown, const SizedBox(height: 20), chart],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: breakdown),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: chart),
          ],
        );
      },
    );
  }

  Widget _buildActivityAnalytics() {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _FocusSectionHeader(
                  eyebrow: 'ACTIVITY ANALYTICS',
                  title: 'Realtime Throughput',
                  detail: 'Read and write performance over time',
                  icon: Icons.monitor_heart_rounded,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (final range in _FocusRange.values)
                    ChoiceChip(
                      label: Text(range.label),
                      selected: range == _range,
                      onSelected: (_) => _selectRange(range),
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _ThroughputCard(
                  label: 'Read throughput',
                  value: formatStorageRate(_drive.readBps),
                  color: Colors.cyanAccent,
                  icon: Icons.south_rounded,
                  samples: [
                    for (final sample in _history?.samples ?? const [])
                      sample.readBps,
                  ],
                ),
                _ThroughputCard(
                  label: 'Write throughput',
                  value: formatStorageRate(_drive.writeBps),
                  color: Colors.purpleAccent,
                  icon: Icons.north_rounded,
                  samples: [
                    for (final sample in _history?.samples ?? const [])
                      sample.writeBps,
                  ],
                ),
              ];
              final width = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _historyLoading
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : StorageActivityChart(
                  samples: _history?.samples ?? const [],
                  height: 260,
                ),
        ],
      ),
    );
  }

  Widget _buildHealthAndForecast() {
    final forecast = _history?.forecast;
    return LayoutBuilder(
      builder: (context, constraints) {
        final health = GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FocusSectionHeader(
                eyebrow: 'HEALTH INFORMATION',
                title: 'Hardware Identity',
                detail: 'SMART and platform-reported metadata',
                icon: Icons.health_and_safety_outlined,
              ),
              const SizedBox(height: 15),
              _InfoRow(
                label: 'SMART status',
                value: _drive.smartStatus ?? 'Unavailable',
              ),
              _InfoRow(
                label: 'Temperature',
                value: _drive.temperatureC == null
                    ? 'Unavailable'
                    : '${_drive.temperatureC!.toStringAsFixed(1)}°C',
              ),
              _InfoRow(label: 'Filesystem', value: _drive.filesystem),
              _InfoRow(label: 'Model', value: _drive.model),
              _InfoRow(label: 'Serial', value: _drive.serial ?? 'Unavailable'),
              _InfoRow(label: 'Interface', value: _drive.interfaceType),
              _InfoRow(label: 'Device', value: _drive.device),
            ],
          ),
        );
        final intelligence = GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FocusSectionHeader(
                eyebrow: 'PREDICTIVE INTELLIGENCE',
                title: 'Capacity Forecast',
                detail: 'Estimated from historical growth',
                icon: Icons.auto_graph_rounded,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  StorageCapacityRing(
                    percent: (forecast?.confidence ?? 0) * 100,
                    color: Colors.tealAccent,
                    size: 102,
                    strokeWidth: 9,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          forecast == null
                              ? '—'
                              : '${(forecast.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'CONFIDENCE',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          forecast?.daysUntilFull == null
                              ? 'No fill date yet'
                              : '${forecast!.daysUntilFull!.toStringAsFixed(0)} days',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          forecast?.daysUntilFull == null
                              ? 'Usage is stable or there is not enough history for a reliable estimate.'
                              : 'Estimated time until this volume reaches full capacity.',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'ACTIVITY HEATMAP · LAST 7 DAYS',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 9),
              StorageHeatmap(cells: _history?.heatmap ?? const []),
            ],
          ),
        );
        if (constraints.maxWidth < 920) {
          return Column(
            children: [health, const SizedBox(height: 20), intelligence],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: health),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: intelligence),
          ],
        );
      },
    );
  }

  Widget _buildScanner() {
    final job = _scanJob;
    final files = [...?job?.largestFiles];
    files.sort(
      (a, b) => _sortFilesBySize
          ? b.sizeBytes.compareTo(a.sizeBytes)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return Container(
      key: _scannerKey,
      child: GlassPanel(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _FocusSectionHeader(
                    eyebrow: 'LARGEST USAGE SCANNER',
                    title: 'What’s Taking Up Space?',
                    detail:
                        'Asynchronous folder and file analysis with an expandable hierarchy',
                    icon: Icons.manage_search_rounded,
                  ),
                ),
                FilledButton.icon(
                  onPressed: job?.status == 'running' ? null : _startScan,
                  icon: const Icon(Icons.radar_rounded, size: 17),
                  label: Text(
                    job == null
                        ? 'Scan Drive'
                        : job.status == 'running'
                        ? 'Scanning…'
                        : 'Scan Again',
                  ),
                ),
              ],
            ),
            if (job == null) ...[
              const SizedBox(height: 20),
              const _ScannerEmptyState(),
            ] else if (job.status == 'running') ...[
              const SizedBox(height: 20),
              _ScanProgress(job: job),
            ] else if (job.status == 'failed') ...[
              const SizedBox(height: 20),
              _InlineError(
                message: job.error ?? 'The usage scan could not be completed.',
              ),
            ] else ...[
              const SizedBox(height: 20),
              _ScanSummary(job: job),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tree = _UsageTree(nodes: job.tree);
                  final table = _LargestFilesTable(
                    files: files,
                    sortBySize: _sortFilesBySize,
                    onSortChanged: (value) =>
                        setState(() => _sortFilesBySize = value),
                  );
                  if (constraints.maxWidth < 980) {
                    return Column(
                      children: [tree, const SizedBox(height: 16), table],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: tree),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: table),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmark() {
    final job = _benchmarkJob;
    return Container(
      key: _benchmarkKey,
      child: GlassPanel(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _FocusSectionHeader(
                    eyebrow: 'BENCHMARK TOOL',
                    title: 'Drive Performance Lab',
                    detail:
                        'Bounded sequential and random I/O tests using a self-cleaning temporary file',
                    icon: Icons.speed_rounded,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: job?.status == 'running'
                      ? null
                      : () => _startBenchmark('quick'),
                  icon: const Icon(Icons.bolt_rounded, size: 17),
                  label: const Text('Quick'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: job?.status == 'running'
                      ? null
                      : () => _startBenchmark('full'),
                  icon: const Icon(Icons.science_outlined, size: 17),
                  label: const Text('Full Benchmark'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (job == null)
              const _BenchmarkEmptyState()
            else if (job.status == 'running')
              _BenchmarkProgress(job: job)
            else if (job.status == 'failed')
              _InlineError(
                message:
                    job.error ??
                    'The benchmark could not write a temporary file on this volume.',
              )
            else if (job.results != null)
              _BenchmarkResultsGrid(results: job.results!),
          ],
        ),
      ),
    );
  }
}

class _FocusAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  const _FocusAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 18)),
    );
  }
}

class _AttributePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _AttributePill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityHistoryChart extends StatelessWidget {
  final List<StorageHistorySample> samples;

  const _CapacityHistoryChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return SizedBox(
        height: 190,
        child: Center(
          child: Text(
            'Capacity history will appear after telemetry has been recorded.',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
        ),
      );
    }
    final minValue = samples
        .map((sample) => sample.capacityPercent)
        .reduce(math.min);
    final maxValue = samples
        .map((sample) => sample.capacityPercent)
        .reduce(math.max);
    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (samples.length - 1).toDouble(),
          minY: math.max(0, minValue - 4),
          maxY: math.min(100, math.max(maxValue + 4, minValue + 8)),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.overlay(context, 0.045),
              strokeWidth: 1,
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < samples.length; index++)
                  FlSpot(index.toDouble(), samples[index].capacityPercent),
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: Colors.cyanAccent,
              barWidth: 2.3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.cyanAccent.withValues(alpha: 0.18),
                    Colors.cyanAccent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 650),
      ),
    );
  }
}

class _MiniStat {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
}

class _MiniStatRow extends StatelessWidget {
  final _MiniStat stat;

  const _MiniStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final color = stat.color ?? AppColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(stat.icon, color: color, size: 17),
          const SizedBox(width: 10),
          Text(
            stat.label,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
          const Spacer(),
          Text(
            stat.value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ThroughputCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final List<double> samples;

  const _ThroughputCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.samples,
  });

  @override
  Widget build(BuildContext context) {
    final peak = samples.isEmpty ? 0.0 : samples.reduce(math.max);
    final minimum = samples.isEmpty ? 0.0 : samples.reduce(math.min);
    final average = samples.isEmpty
        ? 0.0
        : samples.reduce((a, b) => a + b) / samples.length;
    final trend = samples.length < 2 ? 0.0 : samples.last - samples.first;
    final trendLabel = trend.abs() < 1024
        ? 'Stable'
        : trend > 0
        ? 'Rising'
        : 'Falling';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  'Avg ${formatStorageRate(average)} · Peak ${formatStorageRate(peak)}\n'
                  'Min ${formatStorageRate(minimum)} · Trend $trendLabel',
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: StorageSparkline(values: samples, color: color, height: 50),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerEmptyState extends StatelessWidget {
  const _ScannerEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.overlay(context, 0.025),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_special_outlined,
            color: Colors.cyanAccent,
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'Reveal the folders and files consuming this drive',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'The scan runs in the background, skips protected paths it cannot read, and reports progress here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  final StorageScanJob job;

  const _ScanProgress({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: Colors.cyanAccent.withValues(alpha: 0.035),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                '${(job.progress * 100).toStringAsFixed(0)}% scanned',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${job.scannedFiles} files · ${formatStorageBytes(job.scannedBytes)}',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: job.progress,
              minHeight: 8,
              backgroundColor: AppColors.overlay(context, 0.06),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            job.currentPath ?? 'Finalising results…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  final StorageScanJob job;

  const _ScanSummary({required this.job});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(
          label: 'Files indexed',
          value: '${job.scannedFiles}',
          icon: Icons.insert_drive_file_outlined,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          label: 'Data scanned',
          value: formatStorageBytes(job.scannedBytes),
          icon: Icons.data_usage_rounded,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          label: 'Largest files',
          value: '${job.largestFiles.length}',
          icon: Icons.format_list_numbered_rounded,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: AppColors.overlay(context, 0.03),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 17),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _UsageTree extends StatelessWidget {
  final List<StorageUsageNode> nodes;

  const _UsageTree({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'LARGEST FOLDERS',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          if (nodes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No readable folders were found.'),
            )
          else
            for (final node in nodes) _UsageNodeTile(node: node),
        ],
      ),
    );
  }
}

class _UsageNodeTile extends StatelessWidget {
  final StorageUsageNode node;

  const _UsageNodeTile({required this.node});

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        const Icon(Icons.folder_rounded, color: Colors.amberAccent, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          formatStorageBytes(node.sizeBytes),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(
          '${node.percentOfDisk.toStringAsFixed(1)}%',
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 8),
        ),
      ],
    );
    if (node.children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: title,
      );
    }
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.only(left: 16),
      title: title,
      children: [
        for (final child in node.children) _UsageNodeTile(node: child),
      ],
    );
  }
}

class _LargestFilesTable extends StatelessWidget {
  final List<StorageUsageFile> files;
  final bool sortBySize;
  final ValueChanged<bool> onSortChanged;

  const _LargestFilesTable({
    required this.files,
    required this.sortBySize,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  'LARGEST FILES',
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Size')),
                    ButtonSegment(value: false, label: Text('Name')),
                  ],
                  selected: {sortBySize},
                  onSelectionChanged: (value) => onSortChanged(value.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 8)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: files.isEmpty
                ? const Center(child: Text('No readable files were found.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: files.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.border(context)),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 17,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 8,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatStorageBytes(file.sizeBytes),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${file.percentOfDisk.toStringAsFixed(2)}% of used',
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontSize: 7,
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

class _BenchmarkEmptyState extends StatelessWidget {
  const _BenchmarkEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          const Icon(Icons.speed_rounded, color: Colors.purpleAccent, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Measure real sequential and random throughput',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Quick uses 16 MB. Full uses 64 MB. Temporary test data is removed automatically.',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkProgress extends StatelessWidget {
  final StorageBenchmarkJob job;

  const _BenchmarkProgress({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                '${job.mode == 'quick' ? 'Quick' : 'Full'} benchmark in progress',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${(job.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: job.progress,
              minHeight: 8,
              color: Colors.purpleAccent,
              backgroundColor: AppColors.overlay(context, 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkResultsGrid extends StatelessWidget {
  final StorageBenchmarkResults results;

  const _BenchmarkResultsGrid({required this.results});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Sequential read', results.sequentialReadMbps, Colors.cyanAccent),
      ('Sequential write', results.sequentialWriteMbps, Colors.purpleAccent),
      ('Random read', results.randomReadMbps, Colors.lightBlueAccent),
      ('Random write', results.randomWriteMbps, Colors.orangeAccent),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _BenchmarkResultCard(
                  label: metric.$1,
                  value: metric.$2,
                  color: metric.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BenchmarkResultCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BenchmarkResultCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final comparison = value >= 1000
        ? 'Exceptional'
        : value >= 500
        ? 'High performance'
        : value >= 150
        ? 'Responsive'
        : 'Entry level';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '${animated.toStringAsFixed(1)} MB/s',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                comparison,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}

class _FocusSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String detail;
  final IconData icon;

  const _FocusSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.cyanAccent, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                detail,
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
    );
  }
}
