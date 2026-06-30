import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/benchmark_comparison.dart';
import '../../models/benchmark_models.dart';
import '../../services/benchmark_comparison_provider.dart';
import '../../services/benchmark_privacy_preferences.dart';
import '../../services/benchmark_service.dart';

class BenchmarkPage extends StatefulWidget {
  final BenchmarkService? service;
  final BenchmarkComparisonCoordinator? comparisonCoordinator;
  final BenchmarkPrivacyPreferences? privacyPreferences;

  const BenchmarkPage({
    super.key,
    this.service,
    this.comparisonCoordinator,
    this.privacyPreferences,
  });

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  late final BenchmarkService _service;
  late final BenchmarkComparisonCoordinator _comparisonCoordinator;
  late final BenchmarkPrivacyPreferences _privacyPreferences;
  BenchmarkStatus _status = const BenchmarkStatus.idle();
  BenchmarkResult? _latest;
  List<BenchmarkResult> _results = const [];
  Timer? _pollTimer;
  bool _loading = true;
  bool _actionPending = false;
  bool _polling = false;
  String? _error;
  BenchmarkComparisonFilter _comparisonFilter =
      BenchmarkComparisonFilter.identicalCpu;
  BenchmarkComparison? _comparison;
  bool _comparisonLoading = false;
  final Set<int> _promptedThisSession = <int>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BenchmarkService();
    _comparisonCoordinator =
        widget.comparisonCoordinator ?? BenchmarkComparisonCoordinator();
    _privacyPreferences =
        widget.privacyPreferences ?? BenchmarkPrivacyPreferences();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<dynamic>([
        _service.fetchStatus(),
        _service.fetchLatest(),
        _service.fetchResults(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _status = values[0] as BenchmarkStatus;
        _latest = values[1] as BenchmarkResult?;
        _results = values[2] as List<BenchmarkResult>;
        _loading = false;
        _error = null;
      });
      if (_status.isRunning) _startPolling();
      await _updateComparison();
      if (_status.state == BenchmarkRunState.completed) {
        await _maybePromptForSubmission();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _startBenchmark() async {
    if (_status.isRunning || _actionPending) return;
    setState(() {
      _actionPending = true;
      _error = null;
    });
    try {
      final status = await _service.start();
      if (!mounted) return;
      setState(() => _status = status);
      _startPolling();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _cancelBenchmark() async {
    if (!_status.isRunning || _actionPending) return;
    setState(() => _actionPending = true);
    try {
      final status = await _service.cancel();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 650),
      (_) => _pollStatus(),
    );
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    if (_polling) return;
    _polling = true;
    try {
      final status = await _service.fetchStatus();
      if (!mounted) return;
      final justFinished = _status.isRunning && status.isTerminal;
      setState(() {
        _status = status;
        if (status.state == BenchmarkRunState.failed) {
          _error =
              status.errorMessage ?? 'The benchmark could not be completed.';
        }
      });
      if (justFinished) {
        _pollTimer?.cancel();
        await _refreshResults();
        if (status.state == BenchmarkRunState.completed) {
          await _maybePromptForSubmission();
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      _polling = false;
    }
  }

  Future<void> _refreshResults() async {
    try {
      final values = await Future.wait<dynamic>([
        _service.fetchLatest(),
        _service.fetchResults(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _latest = values[0] as BenchmarkResult?;
        _results = values[1] as List<BenchmarkResult>;
      });
      await _updateComparison();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _updateComparison() async {
    final result = _latest;
    if (result == null) {
      if (mounted) setState(() => _comparison = null);
      return;
    }
    if (mounted) setState(() => _comparisonLoading = true);
    try {
      final comparison = await _comparisonCoordinator.compare(
        result: result,
        results: _results,
        filter: _comparisonFilter,
      );
      if (!mounted) return;
      setState(() => _comparison = comparison);
    } finally {
      if (mounted) setState(() => _comparisonLoading = false);
    }
  }

  Future<void> _setComparisonFilter(BenchmarkComparisonFilter filter) async {
    if (_comparisonFilter == filter) return;
    setState(() => _comparisonFilter = filter);
    await _updateComparison();
  }

  Future<void> _showSubmissionConsent(BenchmarkResult result) async {
    if (!mounted) return;
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => const _SubmissionConsentDialog(),
    );
    if (submit != true || !mounted) return;
    final outcome = await _comparisonCoordinator.submitAnonymously(result);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _maybePromptForSubmission() async {
    final result = _latest;
    if (result == null ||
        _promptedThisSession.contains(result.id) ||
        !await _privacyPreferences.shouldPromptForResult(result.id)) {
      return;
    }
    _promptedThisSession.add(result.id);
    await _privacyPreferences.markPrompted(result.id);
    await _showSubmissionConsent(result);
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst(
      RegExp(r'^(Exception|Bad state):\s*'),
      '',
    );
    if (message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('socket')) {
      return 'Benchmark service is unavailable. Check that the HardwareMon backend is running.';
    }
    return message.isEmpty
        ? 'Benchmark Mode is temporarily unavailable.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('benchmark-page-scroll'),
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _ErrorBanner(message: _error!, onRetry: _load),
            const SizedBox(height: 14),
          ],
          if (_loading)
            const _BenchmarkCard(
              child: SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else ...[
            _buildOverview(),
            const SizedBox(height: 16),
            if (_latest != null) _buildScores(_latest!),
            if (_latest != null) const SizedBox(height: 16),
            if (_latest != null) _buildComparison(),
            if (_latest != null) const SizedBox(height: 16),
            _buildHistory(),
          ],
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
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.speed_rounded, color: AppColors.accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Benchmark',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                'Controlled local performance testing · HardwareMon score v1',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        _StatePill(status: _status),
      ],
    );
  }

  Widget _buildOverview() {
    return _BenchmarkCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status.isRunning
                    ? _status.currentTest ?? 'Benchmark in progress'
                    : 'Measure this system',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CPU single- and multi-thread performance, memory throughput, and safe temporary-file disk performance.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  height: 1.45,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              if (_status.isRunning) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _status.progress / 100,
                    minHeight: 10,
                    backgroundColor: AppColors.overlay(context, 0.06),
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      '${_status.progress.toStringAsFixed(0)}% complete',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _durationLabel(_status.elapsedTime),
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ] else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _TestChip(icon: Icons.memory_rounded, label: 'CPU'),
                    _TestChip(icon: Icons.view_in_ar_rounded, label: 'Memory'),
                    _TestChip(icon: Icons.storage_rounded, label: 'Disk'),
                    _TestChip(icon: Icons.timer_outlined, label: 'Lightweight'),
                  ],
                ),
            ],
          );

          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _status.isRunning || _actionPending
                    ? null
                    : _startBenchmark,
                icon: _actionPending && !_status.isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Benchmark'),
              ),
              if (_status.isRunning) ...[
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: _actionPending ? null : _cancelBenchmark,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Cancel safely'),
                ),
              ],
              const SizedBox(height: 11),
              Text(
                'No administrator or root access required. Temporary disk data is removed automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 9,
                  height: 1.35,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [intro, const SizedBox(height: 22), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 7, child: intro),
              const SizedBox(width: 32),
              SizedBox(width: 210, child: actions),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.025);
  }

  Widget _buildScores(BenchmarkResult result) {
    final cards = [
      ('Overall', result.overallScore, Icons.bolt_rounded, AppColors.accent),
      ('CPU', result.cpuScore, Icons.memory_rounded, Colors.purpleAccent),
      ('Memory', result.memoryScore, Icons.view_in_ar_rounded, Colors.cyan),
      ('Disk', result.diskScore, Icons.storage_rounded, Colors.orange),
    ];
    return _BenchmarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Latest HardwareMon score',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _showResult(result),
                child: const Text('View details'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final spacing = 10.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    SizedBox(
                      width: width,
                      child:
                          _ScoreCard(
                                label: cards[i].$1,
                                score: cards[i].$2,
                                icon: cards[i].$3,
                                color: cards[i].$4,
                              )
                              .animate(delay: (70 * i).ms)
                              .fadeIn()
                              .scaleXY(begin: 0.97),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.textMuted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a HardwareMon benchmark score, not a Geekbench or Cinebench score. Results can vary with background apps, power mode, thermals, and battery state.',
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    final comparison = _comparison;
    return _BenchmarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: Colors.purpleAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Performance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Version-compatible comparison results',
                      style: TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              _ComparisonSourcePill(
                label: comparison?.sourceLabel ?? 'Local history',
                offline: comparison?.offlineFallback ?? true,
              ),
            ],
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in BenchmarkComparisonFilter.values) ...[
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: filter == _comparisonFilter,
                    onSelected: (_) => _setComparisonFilter(filter),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (filter != BenchmarkComparisonFilter.values.last)
                    const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_comparisonLoading)
            const SizedBox(
              height: 190,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (comparison == null || !comparison.available)
            _ComparisonUnavailable(
              message:
                  comparison?.unavailableReason ??
                  'Comparison data is not available yet.',
            )
          else ...[
            Text(
              comparison.sampleSize < 2
                  ? 'This result starts your local baseline.'
                  : 'Your system performs better than ${comparison.percentile.round()}% of matching local results.',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${comparison.sampleSize} result${comparison.sampleSize == 1 ? '' : 's'} in this ${comparison.filter.label.toLowerCase()} set · HardwareMon score v${_latest!.benchmarkVersion}',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 18),
            _ComparisonStats(comparison: comparison),
            const SizedBox(height: 22),
            const Text(
              'Comparison chart',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'Your score against the selected result set',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              child: _ComparisonChart(
                yourScore: _latest!.overallScore,
                average: comparison.averageScore,
                topTen: comparison.topTenScore,
                highest: comparison.highestScore,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Performance Insight',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final insight in comparison.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        insight,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 360.ms).slideY(begin: 0.02);
  }

  Widget _buildHistory() {
    final visibleResults = _results.take(20).toList(growable: false);
    return _BenchmarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Previous results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Compare repeat runs on this machine under similar conditions.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 14),
          if (visibleResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.overlay(context, 0.035),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.query_stats_rounded,
                    color: AppColors.textMuted(context),
                    size: 30,
                  ),
                  const SizedBox(height: 9),
                  const Text('Your first result will appear here.'),
                ],
              ),
            )
          else
            for (var index = 0; index < visibleResults.length; index++) ...[
              _ResultRow(
                result: visibleResults[index],
                previous: index + 1 < visibleResults.length
                    ? visibleResults[index + 1]
                    : null,
                onTap: () => _showResult(visibleResults[index]),
              ),
              if (index != visibleResults.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }

  Future<void> _showResult(BenchmarkResult result) {
    return showDialog<void>(
      context: context,
      builder: (context) => _ResultDetails(result: result),
    );
  }
}

class _BenchmarkCard extends StatelessWidget {
  final Widget child;

  const _BenchmarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(color: AppColors.shadow(context), blurRadius: 18),
        ],
      ),
      child: child,
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;
  final Color color;

  const _ScoreCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              '$score',
              key: ValueKey(score),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            label,
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

class _ResultRow extends StatelessWidget {
  final BenchmarkResult result;
  final BenchmarkResult? previous;
  final VoidCallback onTap;

  const _ResultRow({
    required this.result,
    required this.previous,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delta =
        previous == null ||
            previous!.benchmarkVersion != result.benchmarkVersion
        ? null
        : result.overallScore - previous!.overallScore;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${result.overallScore}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMM yyyy · HH:mm').format(result.timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'v${result.benchmarkVersion}  ·  CPU ${result.cpuScore}  ·  Memory ${result.memoryScore}  ·  Disk ${result.diskScore}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            if (delta != null) ...[
              Text(
                '${delta >= 0 ? '+' : ''}$delta',
                style: TextStyle(
                  color: delta >= 0 ? Colors.greenAccent : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDetails extends StatelessWidget {
  final BenchmarkResult result;

  const _ResultDetails({required this.result});

  @override
  Widget build(BuildContext context) {
    final cpuSingle = _nestedNumber(
      result.rawResult,
      'cpu_single',
      'operations_per_second',
    );
    final cpuMulti = _nestedNumber(
      result.rawResult,
      'cpu_multi',
      'operations_per_second',
    );
    final memory = _nestedNumber(
      result.rawResult,
      'memory',
      'throughput_mib_s',
    );
    final diskRead = _nestedNumber(result.rawResult, 'disk', 'read_mib_s');
    final diskWrite = _nestedNumber(result.rawResult, 'disk', 'write_mib_s');
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.speed_rounded),
          SizedBox(width: 10),
          Text('Benchmark result'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.overallScore}',
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'HardwareMon score · version ${result.benchmarkVersion}',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailMetric(
                    label: 'CPU score',
                    value: '${result.cpuScore}',
                  ),
                  _DetailMetric(
                    label: 'Memory score',
                    value: '${result.memoryScore}',
                  ),
                  _DetailMetric(
                    label: 'Disk score',
                    value: '${result.diskScore}',
                  ),
                  _DetailMetric(
                    label: 'Duration',
                    value: _durationLabel(result.duration),
                  ),
                  _DetailMetric(
                    label: 'Single thread',
                    value: '${cpuSingle.toStringAsFixed(1)} ops/s',
                  ),
                  _DetailMetric(
                    label: 'Multi thread',
                    value: '${cpuMulti.toStringAsFixed(1)} ops/s',
                  ),
                  _DetailMetric(
                    label: 'Memory',
                    value: '${memory.toStringAsFixed(0)} MiB/s',
                  ),
                  _DetailMetric(
                    label: 'Disk read',
                    value: '${diskRead.toStringAsFixed(0)} MiB/s',
                  ),
                  _DetailMetric(
                    label: 'Disk write',
                    value: '${diskWrite.toStringAsFixed(0)} MiB/s',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                result.cpuModel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${result.cpuCores} cores / ${result.cpuThreads} threads · ${result.gpuModel ?? 'GPU unavailable'}',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_bytesLabel(result.ramTotal)} RAM${result.ramSpeedMhz == null ? '' : ' @ ${result.ramSpeedMhz} MHz'} · ${result.storageType ?? 'Storage type unavailable'} · ${result.operatingSystem}',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                result.platform,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
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
      width: 158,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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

class _StatePill extends StatelessWidget {
  final BenchmarkStatus status;

  const _StatePill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.state) {
      BenchmarkRunState.running => ('RUNNING', AppColors.accent),
      BenchmarkRunState.completed => ('COMPLETE', Colors.greenAccent),
      BenchmarkRunState.failed => ('FAILED', Colors.redAccent),
      BenchmarkRunState.cancelled => ('CANCELLED', Colors.orange),
      BenchmarkRunState.idle => ('READY', Colors.greenAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _TestChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TestChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
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

class _ComparisonStats extends StatelessWidget {
  final BenchmarkComparison comparison;

  const _ComparisonStats({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Percentile',
        '${comparison.percentile.round()}%',
        Icons.percent_rounded,
      ),
      (
        'Average · identical CPU',
        _optionalScore(comparison.averageIdenticalCpu),
        Icons.memory_rounded,
      ),
      (
        'Average · CPU + GPU',
        _optionalScore(comparison.averageIdenticalCpuAndGpu),
        Icons.developer_board_rounded,
      ),
      (
        'Best recorded',
        '${comparison.highestScore}',
        Icons.emoji_events_rounded,
      ),
      (
        'Median',
        comparison.medianScore.round().toString(),
        Icons.balance_rounded,
      ),
      ('Lowest', '${comparison.lowestScore}', Icons.south_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        const spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _RankingMetric(
                  label: metric.$1,
                  value: metric.$2,
                  icon: metric.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RankingMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RankingMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
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

class _ComparisonChart extends StatelessWidget {
  final int yourScore;
  final double average;
  final int topTen;
  final int highest;

  const _ComparisonChart({
    required this.yourScore,
    required this.average,
    required this.topTen,
    required this.highest,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      yourScore.toDouble(),
      average,
      topTen.toDouble(),
      highest.toDouble(),
    ];
    final maxValue = values.reduce(math.max);
    final maxY = math.max(100.0, maxValue * 1.18);
    const labels = ['Your score', 'Average', 'Top 10%', 'Highest'];
    final colors = [
      AppColors.accent,
      Colors.blueGrey,
      Colors.purpleAccent,
      Colors.orange,
    ];
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${labels[group.x]}\n${rod.toY.round()}',
                const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border(context), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 8,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < values.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colors[index].withValues(alpha: 0.45),
                      colors[index],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }
}

class _ComparisonSourcePill extends StatelessWidget {
  final String label;
  final bool offline;

  const _ComparisonSourcePill({required this.label, required this.offline});

  @override
  Widget build(BuildContext context) {
    final color = offline ? Colors.greenAccent : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offline ? Icons.offline_bolt_rounded : Icons.cloud_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonUnavailable extends StatelessWidget {
  final String message;

  const _ComparisonUnavailable({required this.message});

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
          Icon(Icons.insights_rounded, color: AppColors.textMuted(context)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '$message HardwareMon remains fully functional in local-only mode.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionConsentDialog extends StatelessWidget {
  const _SubmissionConsentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Help improve HardwareMon?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Anonymously submit this benchmark to improve future comparisons. Nothing is uploaded unless you choose Submit.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              const _PrivacyList(
                title: 'Included',
                color: Colors.greenAccent,
                items: [
                  'Benchmark scores and version',
                  'CPU and GPU models, plus memory and storage class',
                  'Core/thread count, RAM capacity and available speed',
                  'Operating system',
                ],
              ),
              const SizedBox(height: 14),
              const _PrivacyList(
                title: 'Never included',
                color: Colors.orange,
                items: [
                  'Usernames, device names, or serial numbers',
                  'IP addresses or other network identifiers',
                  'Installed software or personal files',
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Cloud submission is prepared for a future service and is not enabled in this release.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep local only'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Submit anonymously'),
        ),
      ],
    );
  }
}

class _PrivacyList extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;

  const _PrivacyList({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 5, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _optionalScore(double? value) =>
    value == null ? 'Unavailable' : value.round().toString();

double _nestedNumber(Map<String, dynamic> root, String section, String key) {
  final value = root[section];
  if (value is! Map) return 0;
  return (value[key] as num?)?.toDouble() ?? 0;
}

String _durationLabel(double seconds) {
  final duration = Duration(milliseconds: math.max(0, seconds * 1000).round());
  final minutes = duration.inMinutes;
  final remainder = duration.inSeconds.remainder(60);
  return minutes > 0
      ? '${minutes}m ${remainder}s'
      : '${seconds.toStringAsFixed(1)}s';
}

String _bytesLabel(int bytes) {
  if (bytes <= 0) return 'Unknown';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
