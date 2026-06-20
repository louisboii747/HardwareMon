import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/storage_models.dart';
import '../../services/storage_service.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/storage_visuals.dart';
import '../storage_focus_screen.dart';

enum _StorageRange {
  live('Live', 0),
  hour('1 Hour', 3600),
  day('24 Hours', 86400),
  week('7 Days', 604800),
  month('30 Days', 2592000);

  final String label;
  final int seconds;

  const _StorageRange(this.label, this.seconds);
}

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final StorageService _service = StorageService();
  final List<StorageHistorySample> _liveHistory = [];
  Timer? _timer;
  StorageSnapshot? _snapshot;
  StorageHistory? _history;
  _StorageRange _range = _StorageRange.live;
  bool _loading = true;
  bool _historyLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refresh(silent: true)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final snapshot = await _service.fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
        _liveHistory.add(
          StorageHistorySample(
            timestamp: snapshot.sampledAt,
            capacityPercent: snapshot.usedPercent,
            readBps: snapshot.readBps,
            writeBps: snapshot.writeBps,
            temperatureC: snapshot.temperatureC,
          ),
        );
        if (_liveHistory.length > 150) _liveHistory.removeAt(0);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectRange(_StorageRange range) async {
    if (_range == range) return;
    setState(() => _range = range);
    if (range == _StorageRange.live) return;
    setState(() => _historyLoading = true);
    try {
      final history = await _service.fetchHistory(
        rangeSeconds: range.seconds,
        points: range == _StorageRange.month ? 720 : 480,
      );
      if (!mounted || _range != range) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
      _toast('Historical telemetry is unavailable: $error', error: true);
    }
  }

  List<StorageHistorySample> get _activitySamples {
    return _range == _StorageRange.live
        ? _liveHistory
        : _history?.samples ?? const [];
  }

  void _openDrive(
    StorageDrive drive, {
    StorageFocusAction initialAction = StorageFocusAction.overview,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        transitionDuration: const Duration(milliseconds: 720),
        reverseTransitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.965, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: StorageFocusScreen(
              initialDrive: drive,
              initialAction: initialAction,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInExplorer(StorageDrive drive) async {
    try {
      await _service.openDrive(drive.id);
    } catch (error) {
      _toast('Could not open ${drive.mountPoint}: $error', error: true);
    }
  }

  Future<void> _copyPath(StorageDrive drive) async {
    await Clipboard.setData(ClipboardData(text: drive.mountPoint));
    _toast('${drive.mountPoint} copied');
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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
    final snapshot = _snapshot;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(snapshot),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _StorageErrorBanner(onRetry: _refresh),
            ],
            const SizedBox(height: 20),
            _buildOverview(snapshot),
            const SizedBox(height: 20),
            _buildAnalyticsRow(snapshot),
            const SizedBox(height: 20),
            _buildDriveExplorer(snapshot),
            const SizedBox(height: 20),
            _buildInsights(snapshot),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StorageSnapshot? snapshot) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Storage',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Live drive telemetry, health intelligence, capacity forecasting, and performance analytics.',
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 12),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (snapshot != null) ...[
          _ScorePill(score: snapshot.storageScore),
          StorageHealthBadge(
            health: snapshot.health,
            label: '${snapshot.drives.length} drives',
          ),
        ],
        Tooltip(
          message: 'Refresh storage telemetry',
          child: IconButton(
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildOverview(StorageSnapshot? snapshot) {
    final readHistory = [for (final sample in _liveHistory) sample.readBps];
    final writeHistory = [for (final sample in _liveHistory) sample.writeBps];
    final cards = <Widget>[
      _StorageOverviewCard(
        key: const ValueKey('storage-overview-total'),
        title: 'Total Storage',
        icon: Icons.dns_rounded,
        color: Colors.cyanAccent,
        value: snapshot == null
            ? 'Connecting…'
            : formatStorageBytes(snapshot.totalCapacity),
        detail: snapshot == null
            ? 'Waiting for mounted volumes'
            : '${formatStorageBytes(snapshot.usedCapacity)} used · ${formatStorageBytes(snapshot.freeCapacity)} free',
        trailing: StorageCapacityRing(
          percent: snapshot?.usedPercent ?? 0,
          color: Colors.cyanAccent,
          size: 72,
          strokeWidth: 7,
        ),
        expandedDetails: snapshot == null
            ? const ['Waiting for the first storage sample']
            : [
                '${snapshot.usedPercent.toStringAsFixed(1)}% of total capacity is in use',
                '${formatStorageBytes(snapshot.usedCapacity)} allocated',
                '${formatStorageBytes(snapshot.freeCapacity)} available',
              ],
      ),
      _StorageOverviewCard(
        key: const ValueKey('storage-overview-read'),
        title: 'Read Speed',
        icon: Icons.south_rounded,
        color: Colors.lightBlueAccent,
        value: formatStorageRate(snapshot?.readBps ?? 0),
        detail: 'Peak ${formatStorageRate(snapshot?.peakReadBps ?? 0)}',
        graph: StorageSparkline(
          values: readHistory,
          color: Colors.lightBlueAccent,
          height: 42,
        ),
        expandedDetails: [
          'Current ${formatStorageRate(snapshot?.readBps ?? 0)}',
          'Session peak ${formatStorageRate(snapshot?.peakReadBps ?? 0)}',
          '${readHistory.length} realtime samples retained',
        ],
      ),
      _StorageOverviewCard(
        key: const ValueKey('storage-overview-write'),
        title: 'Write Speed',
        icon: Icons.north_rounded,
        color: Colors.purpleAccent,
        value: formatStorageRate(snapshot?.writeBps ?? 0),
        detail: 'Peak ${formatStorageRate(snapshot?.peakWriteBps ?? 0)}',
        graph: StorageSparkline(
          values: writeHistory,
          color: Colors.purpleAccent,
          height: 42,
        ),
        expandedDetails: [
          'Current ${formatStorageRate(snapshot?.writeBps ?? 0)}',
          'Session peak ${formatStorageRate(snapshot?.peakWriteBps ?? 0)}',
          '${writeHistory.length} realtime samples retained',
        ],
      ),
      _StorageOverviewCard(
        key: const ValueKey('storage-overview-temperature'),
        title: 'Drive Temperature',
        icon: Icons.device_thermostat_rounded,
        color: snapshot == null
            ? Colors.orangeAccent
            : storageHealthColor(snapshot.health),
        value: snapshot?.temperatureC == null
            ? 'Unavailable'
            : '${snapshot!.temperatureC!.toStringAsFixed(0)}°C',
        detail: snapshot == null
            ? 'Waiting for health data'
            : snapshot.temperatureC == null
            ? 'SMART temperature not exposed'
            : storageHealthLabel(snapshot.health),
        trailing: snapshot == null
            ? null
            : StorageHealthBadge(health: snapshot.health),
        expandedDetails: [
          snapshot?.temperatureC == null
              ? 'Temperature is not exposed by this platform or drive'
              : 'Warmest detected drive is ${snapshot!.temperatureC!.toStringAsFixed(1)}°C',
          'Overall health: ${storageHealthLabel(snapshot?.health ?? StorageHealth.healthy)}',
          'Unsupported SMART fields remain explicitly unavailable',
        ],
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsRow(StorageSnapshot? snapshot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fleet = _ExpandableGlassCard(
          eyebrow: 'STORAGE FLEET',
          title: 'Drive Pulse',
          detail: 'Mounted volumes ranked by current activity',
          icon: Icons.view_list_rounded,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: StorageFleetView(
              drives: snapshot?.drives ?? const [],
              onSelected: _openDrive,
            ),
          ),
        );
        final activity = _ExpandableGlassCard(
          eyebrow: 'ACTIVITY',
          title: 'Storage Activity Timeline',
          detail: 'Read, write, and combined throughput',
          icon: Icons.show_chart_rounded,
          trailing: _RangeSelector(selected: _range, onSelected: _selectRange),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _ChartLegend(color: Colors.cyanAccent, label: 'Read'),
                  _ChartLegend(color: Colors.purpleAccent, label: 'Write'),
                  _ChartLegend(color: Colors.greenAccent, label: 'Combined'),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _historyLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        height: 236,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : StorageActivityChart(
                        key: ValueKey(_range),
                        samples: _activitySamples,
                        height: 236,
                      ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 980) {
          return Column(
            children: [fleet, const SizedBox(height: 20), activity],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: fleet),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: activity),
          ],
        );
      },
    );
  }

  Widget _buildDriveExplorer(StorageSnapshot? snapshot) {
    final drives = snapshot?.drives ?? const <StorageDrive>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          eyebrow: 'DRIVE EXPLORER',
          title: 'Mounted Storage',
          detail:
              'Open a drive for capacity analytics, health, scanning, and benchmarking',
          icon: Icons.storage_rounded,
        ),
        const SizedBox(height: 14),
        if (drives.isEmpty)
          GlassPanel(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.textMuted(context),
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loading
                        ? 'Discovering mounted drives…'
                        : 'No supported mounted drives were detected.',
                    style: TextStyle(color: AppColors.textMuted(context)),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 700
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final drive in drives)
                    SizedBox(
                      width: width,
                      child: StorageDriveCard(
                        key: ValueKey(drive.id),
                        drive: drive,
                        onOpen: () => _openDrive(drive),
                        onOpenPath: () => _openInExplorer(drive),
                        onCopy: () => _copyPath(drive),
                        onRefresh: _refresh,
                        onScan: () => _openDrive(
                          drive,
                          initialAction: StorageFocusAction.scan,
                        ),
                        onBenchmark: () => _openDrive(
                          drive,
                          initialAction: StorageFocusAction.benchmark,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildInsights(StorageSnapshot? snapshot) {
    final insights = snapshot?.insights ?? const <StorageInsight>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          eyebrow: 'HEALTH ENGINE',
          title: 'Storage Intelligence',
          detail: 'Capacity, temperature, and SMART-aware recommendations',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 14),
        if (insights.isEmpty)
          _InsightCard(
            key: const ValueKey('storage-insight-building'),
            insight: const StorageInsight(
              severity: StorageHealth.healthy,
              title: 'Building storage intelligence',
              message:
                  'HardwareMon will surface health and capacity insights as telemetry arrives.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 2 : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 14)) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final insight in insights)
                    SizedBox(
                      width: width,
                      child: _InsightCard(
                        key: ValueKey('${insight.title}-${insight.message}'),
                        insight: insight,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _StorageOverviewCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String detail;
  final Widget? trailing;
  final Widget? graph;
  final List<String> expandedDetails;

  const _StorageOverviewCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.detail,
    this.trailing,
    this.graph,
    this.expandedDetails = const [],
  });

  @override
  State<_StorageOverviewCard> createState() => _StorageOverviewCardState();
}

class _StorageOverviewCardState extends State<_StorageOverviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: _expanded ? 'Collapse card' : 'Expand card',
                onPressed: () => setState(() => _expanded = !_expanded),
                visualDensity: VisualDensity.compact,
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: const Icon(Icons.expand_more_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        widget.value,
                        key: ValueKey(widget.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 9,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: widget.trailing == null ? 0 : 8),
              ?widget.trailing,
            ],
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              reverseDuration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ?widget.graph,
                          if (widget.graph != null) const SizedBox(height: 10),
                          for (final detail in widget.expandedDetails)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: widget.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      detail,
                                      style: TextStyle(
                                        color: AppColors.textMuted(context),
                                        fontSize: 9,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class StorageDriveCard extends StatefulWidget {
  final StorageDrive drive;
  final VoidCallback onOpen;
  final Future<void> Function() onOpenPath;
  final Future<void> Function() onCopy;
  final Future<void> Function() onRefresh;
  final VoidCallback onScan;
  final VoidCallback onBenchmark;

  const StorageDriveCard({
    super.key,
    required this.drive,
    required this.onOpen,
    required this.onOpenPath,
    required this.onCopy,
    required this.onRefresh,
    required this.onScan,
    required this.onBenchmark,
  });

  @override
  State<StorageDriveCard> createState() => _DriveCardState();
}

class _DriveCardState extends State<StorageDriveCard> {
  bool _hovered = false;
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  Future<void> _showMenu(TapDownDetails details) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open analytics')),
        PopupMenuItem(value: 'path', child: Text('Open drive')),
        PopupMenuItem(value: 'copy', child: Text('Copy path')),
        PopupMenuItem(value: 'refresh', child: Text('Refresh')),
        PopupMenuItem(value: 'scan', child: Text('Scan usage')),
        PopupMenuItem(value: 'benchmark', child: Text('Run benchmark')),
      ],
    );
    switch (action) {
      case 'open':
        widget.onOpen();
      case 'path':
        await widget.onOpenPath();
      case 'copy':
        await widget.onCopy();
      case 'refresh':
        await widget.onRefresh();
      case 'scan':
        widget.onScan();
      case 'benchmark':
        widget.onBenchmark();
    }
  }

  @override
  Widget build(BuildContext context) {
    final drive = widget.drive;
    final color = storageHealthColor(drive.health);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        onSecondaryTapDown: _showMenu,
        child: AnimatedScale(
          scale: _hovered ? 1.012 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: color.withValues(alpha: 0.1),
                          border: Border.all(
                            color: color.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          drive.removable
                              ? Icons.usb_rounded
                              : Icons.storage_rounded,
                          color: color,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drive.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${drive.mountPoint} · ${drive.filesystem}',
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
                      Tooltip(
                        message: _expanded
                            ? 'Collapse drive card'
                            : 'Expand drive card',
                        child: IconButton(
                          onPressed: _toggleExpanded,
                          visualDensity: VisualDensity.compact,
                          icon: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: const Icon(
                              Icons.expand_more_rounded,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      StorageHealthBadge(health: drive.health),
                      _CompactDriveBadge(
                        icon: Icons.score_rounded,
                        label: '${drive.score}/100',
                        color: color,
                      ),
                      _CompactDriveBadge(
                        icon: Icons.memory_rounded,
                        label: drive.interfaceType,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${drive.usedPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'used',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatStorageBytes(drive.freeBytes)} free',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: drive.usedPercent / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.overlay(context, 0.06),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final metricWidth = math.max(
                        88.0,
                        (constraints.maxWidth - 8) / 2,
                      );
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: metricWidth,
                            child: _DriveMetric(
                              label: 'Capacity',
                              value: formatStorageBytes(drive.totalBytes),
                            ),
                          ),
                          SizedBox(
                            width: metricWidth,
                            child: _DriveMetric(
                              label: 'Read',
                              value: formatStorageRate(drive.readBps),
                              color: Colors.cyanAccent,
                            ),
                          ),
                          SizedBox(
                            width: metricWidth,
                            child: _DriveMetric(
                              label: 'Write',
                              value: formatStorageRate(drive.writeBps),
                              color: Colors.purpleAccent,
                            ),
                          ),
                          SizedBox(
                            width: metricWidth,
                            child: _DriveMetric(
                              label: 'Temperature',
                              value: drive.temperatureC == null
                                  ? 'Unavailable'
                                  : '${drive.temperatureC!.toStringAsFixed(0)}°C',
                              color: color,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _hovered || _expanded ? 1 : 0.68,
                    duration: const Duration(milliseconds: 180),
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CardAction(
                          icon: Icons.folder_open_rounded,
                          label: 'Open',
                          onTap: widget.onOpenPath,
                        ),
                        _CardAction(
                          icon: Icons.content_copy_rounded,
                          label: 'Copy',
                          onTap: widget.onCopy,
                        ),
                        _CardAction(
                          icon: Icons.manage_search_rounded,
                          label: 'Scan',
                          onTap: () async => widget.onScan(),
                        ),
                        _CardAction(
                          icon: Icons.speed_rounded,
                          label: 'Benchmark',
                          onTap: () async => widget.onBenchmark(),
                        ),
                        _CardAction(
                          icon: _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          label: _expanded ? 'Collapse' : 'Expand',
                          onTap: () async => _toggleExpanded(),
                        ),
                      ],
                    ),
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      reverseDuration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: _expanded
                          ? _DriveExpandedDetails(
                              drive: drive,
                              color: color,
                              onOpenAnalytics: widget.onOpen,
                            )
                          : const SizedBox.shrink(),
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

class _DriveExpandedDetails extends StatelessWidget {
  final StorageDrive drive;
  final Color color;
  final VoidCallback onOpenAnalytics;

  const _DriveExpandedDetails({
    required this.drive,
    required this.color,
    required this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final insight = drive.insights.isEmpty ? null : drive.insights.first;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.border(context), height: 20),
          _DriveDetailRow(label: 'Model', value: drive.model),
          _DriveDetailRow(label: 'Interface', value: drive.interfaceType),
          _DriveDetailRow(label: 'Device', value: drive.device),
          _DriveDetailRow(
            label: 'Serial',
            value: drive.serial ?? 'Unavailable',
          ),
          _DriveDetailRow(
            label: 'SMART',
            value: drive.smartStatus ?? 'Unavailable',
          ),
          if (insight != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    insight.severity == StorageHealth.healthy
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: color,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insight.message,
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
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenAnalytics,
              icon: const Icon(Icons.open_in_full_rounded, size: 15),
              label: const Text('Open full drive analytics'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DriveDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 9,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactDriveBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _CompactDriveBadge({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DriveMetric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 8),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 15,
        icon: Icon(icon),
      ),
    );
  }
}

class _InsightCard extends StatefulWidget {
  final StorageInsight insight;

  const _InsightCard({super.key, required this.insight});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final color = storageHealthColor(insight.severity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.045),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.045), blurRadius: 24),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(
                  insight.severity == StorageHealth.healthy
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'Collapse insight' : 'Expand insight',
                onPressed: () => setState(() => _expanded = !_expanded),
                visualDensity: VisualDensity.compact,
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 260),
                  child: const Icon(Icons.expand_more_rounded, size: 18),
                ),
              ),
            ],
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              reverseDuration: const Duration(milliseconds: 210),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.overlay(context, 0.025),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Text(
                          insight.message,
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableGlassCard extends StatefulWidget {
  final String eyebrow;
  final String title;
  final String detail;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _ExpandableGlassCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  State<_ExpandableGlassCard> createState() => _ExpandableGlassCardState();
}

class _ExpandableGlassCardState extends State<_ExpandableGlassCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Expanded(
          child: _SectionHeader(
            eyebrow: widget.eyebrow,
            title: widget.title,
            detail: widget.detail,
            icon: widget.icon,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: _expanded ? 'Collapse card' : 'Expand card',
          onPressed: () => setState(() => _expanded = !_expanded),
          visualDensity: VisualDensity.compact,
          icon: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: const Icon(Icons.expand_more_rounded, size: 19),
          ),
        ),
      ],
    );

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackControls =
              widget.trailing != null && constraints.maxWidth < 720;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackControls) ...[
                header,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: widget.trailing!),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 10),
                      Flexible(child: widget.trailing!),
                    ],
                  ],
                ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  reverseDuration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  child: _expanded ? widget.child : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? Colors.greenAccent
        : score >= 65
        ? Colors.amberAccent
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Storage Score  $score/100',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String detail;
  final IconData icon;

  const _SectionHeader({
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
            color: AppColors.accent.withValues(alpha: 0.1),
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

class _RangeSelector extends StatelessWidget {
  final _StorageRange selected;
  final ValueChanged<_StorageRange> onSelected;

  const _RangeSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final range in _StorageRange.values)
          ChoiceChip(
            label: Text(range.label),
            selected: selected == range,
            onSelected: (_) => onSelected(range),
            labelStyle: const TextStyle(fontSize: 9),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
        ),
      ],
    );
  }
}

class _StorageErrorBanner extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _StorageErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent,
            size: 19,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Storage telemetry is disconnected. HardwareMon will keep retrying the local backend.',
              style: TextStyle(fontSize: 10),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
