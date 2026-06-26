import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/process_info.dart';
import '../../models/process_preferences.dart';
import '../../services/process_service.dart';
import '../../core/theme/app_colors.dart';

class ProcessesPage extends StatefulWidget {
  final List<ProcessInfo>? initialProcesses;
  final bool autoLoad;
  final Duration refreshInterval;

  const ProcessesPage({
    super.key,
    this.initialProcesses,
    this.autoLoad = true,
    this.refreshInterval = const Duration(seconds: 2),
  });

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  final ProcessPreferences preferences = ProcessPreferences();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'Process search');
  final TextEditingController _searchController = TextEditingController();

  List<ProcessInfo> processes = [];
  Map<int, _ProcessDelta> processDeltas = {};
  bool loading = true;
  bool preferencesReady = false;
  String searchQuery = '';
  String? error;
  DateTime? lastUpdated;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    processes = widget.initialProcesses ?? [];
    loading = widget.initialProcesses == null;
    if (widget.initialProcesses != null) {
      lastUpdated = DateTime.now();
    }
    unawaited(_loadPreferences());
    if (widget.autoLoad) {
      unawaited(loadProcesses());
      _scheduleRefreshTimer();
    }
  }

  Future<void> _loadPreferences() async {
    await preferences.load();
    if (!mounted) return;
    setState(() => preferencesReady = true);
    _scheduleRefreshTimer();
  }

  void _scheduleRefreshTimer() {
    refreshTimer?.cancel();
    if (!widget.autoLoad) return;
    if (!preferences.autoRefresh) return;
    refreshTimer = Timer.periodic(
      widget.refreshInterval,
      (_) => unawaited(loadProcesses(silent: true)),
    );
  }

  Future<void> loadProcesses({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final data = await ProcessService.fetchProcesses();
      final deltas = _calculateDeltas(data);
      if (!mounted) return;
      setState(() {
        processes = data;
        processDeltas = deltas;
        loading = false;
        error = null;
        lastUpdated = DateTime.now();
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }

  Map<int, _ProcessDelta> _calculateDeltas(List<ProcessInfo> nextProcesses) {
    if (processes.isEmpty) return {};
    final previousByPid = {
      for (final process in processes) process.pid: process,
    };
    final deltas = <int, _ProcessDelta>{};

    for (final process in nextProcesses) {
      final previous = previousByPid[process.pid];
      if (previous == null) continue;
      if (previous.startedAt != null &&
          process.startedAt != null &&
          previous.startedAt != process.startedAt) {
        continue;
      }
      final cpuDelta = process.cpu - previous.cpu;
      final memoryDelta = process.ram - previous.ram;
      deltas[process.pid] = _ProcessDelta(
        cpuDelta: cpuDelta,
        memoryDeltaMb: memoryDelta,
      );
    }

    return deltas;
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    preferences.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ProcessInfo> get filteredProcesses {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    final filtered = processes.where((process) {
      if (preferences.hideSystemProcesses && process.isSystem) return false;

      final matchesQuickFilter = switch (preferences.quickFilter) {
        ProcessQuickFilter.all => true,
        ProcessQuickFilter.busy => process.cpu >= 1 || process.ram >= 512,
        ProcessQuickFilter.rising => _isRising(process),
        ProcessQuickFilter.memory => process.ram >= 512,
        ProcessQuickFilter.watched => preferences.isWatched(process.name),
      };
      if (!matchesQuickFilter) return false;

      final matchesSearch =
          normalizedQuery.isEmpty ||
          process.name.toLowerCase().contains(normalizedQuery) ||
          process.pid.toString().contains(normalizedQuery) ||
          (process.username?.toLowerCase().contains(normalizedQuery) ?? false);

      return matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      return switch (preferences.sort) {
        ProcessSort.cpu => b.cpu.compareTo(a.cpu),
        ProcessSort.memory => b.ram.compareTo(a.ram),
        ProcessSort.activity => _activityScore(b).compareTo(_activityScore(a)),
        ProcessSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        ProcessSort.pid => a.pid.compareTo(b.pid),
      };
    });
    return filtered;
  }

  _ProcessDelta _deltaFor(ProcessInfo process) {
    return processDeltas[process.pid] ?? const _ProcessDelta();
  }

  bool _isRising(ProcessInfo process) {
    final delta = _deltaFor(process);
    return delta.cpuDelta >= 0.5 || delta.memoryDeltaMb >= 64;
  }

  double _activityScore(ProcessInfo process) {
    final delta = _deltaFor(process);
    return delta.cpuDelta.abs() + (delta.memoryDeltaMb.abs() / 128);
  }

  _ProcessSummary _buildSummary(List<ProcessInfo> visibleProcesses) {
    final visibleCpu = visibleProcesses.fold<double>(
      0,
      (total, process) => total + process.cpu,
    );
    final visibleMemory = visibleProcesses.fold<double>(
      0,
      (total, process) => total + process.ram,
    );
    final watchedRunning = processes
        .where((process) => preferences.isWatched(process.name))
        .length;
    final topCpu = visibleProcesses.isEmpty
        ? null
        : visibleProcesses.reduce(
            (current, process) => process.cpu > current.cpu ? process : current,
          );
    final topMemory = visibleProcesses.isEmpty
        ? null
        : visibleProcesses.reduce(
            (current, process) => process.ram > current.ram ? process : current,
          );
    final rising = visibleProcesses.where(_isRising).toList(growable: false);
    final topRising = rising.isEmpty
        ? null
        : rising.reduce(
            (current, process) =>
                _activityScore(process) > _activityScore(current)
                ? process
                : current,
          );

    return _ProcessSummary(
      visibleCpu: visibleCpu,
      visibleMemoryMb: visibleMemory,
      watchedRunning: watchedRunning,
      systemHidden: processes.where((process) => process.isSystem).length,
      topCpu: topCpu,
      topMemory: topMemory,
      risingCount: rising.length,
      topRising: topRising,
    );
  }

  Future<void> _setHideSystemProcesses(bool value) async {
    await preferences.setHideSystemProcesses(value);
    if (mounted) setState(() {});
  }

  Future<void> _setAutoRefresh(bool value) async {
    await preferences.setAutoRefresh(value);
    _scheduleRefreshTimer();
    if (mounted) setState(() {});
    if (value && widget.autoLoad) unawaited(loadProcesses(silent: true));
  }

  Future<void> _setCompactDensity(bool value) async {
    await preferences.setCompactDensity(value);
    if (mounted) setState(() {});
  }

  Future<void> _setSort(ProcessSort value) async {
    await preferences.setSort(value);
    if (mounted) setState(() {});
  }

  Future<void> _setQuickFilter(ProcessQuickFilter value) async {
    await preferences.setQuickFilter(value);
    if (mounted) setState(() {});
  }

  Future<void> _toggleWatched(ProcessInfo process) async {
    final wasWatched = preferences.isWatched(process.name);
    await preferences.toggleWatched(process.name);
    if (!mounted) return;
    setState(() {});
    _toast(
      wasWatched
          ? '${process.name} removed from watchlist'
          : '${process.name} added to watchlist',
    );
  }

  Future<void> _clearWatched() async {
    await preferences.clearWatched();
    if (!mounted) return;
    setState(() {});
    _toast('Process watchlist cleared');
  }

  Future<void> _confirmKill(ProcessInfo process) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End process?'),
        content: Text(
          'End ${process.name} (PID ${process.pid})?\n\n'
          'Unsaved work in this application may be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End process'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ProcessService.killProcess(process.pid);
    await loadProcesses();
    if (!mounted) return;
    _toast('End request sent for ${process.name}');
  }

  Future<void> _copyVisibleProcesses() async {
    final visible = filteredProcesses;
    final lines = [
      'HardwareMon Process Snapshot',
      'Captured: ${DateTime.now().toIso8601String()}',
      'Visible processes: ${visible.length} of ${processes.length}',
      'Filter: ${preferences.quickFilter.label}',
      'Sort: ${preferences.sort.label}',
      '',
      'Name,PID,CPU %,CPU Delta,Memory,Memory Delta,Type,User,Status',
      for (final process in visible.take(120))
        [
          process.name,
          process.pid,
          process.cpu.toStringAsFixed(1),
          _formatPercentDelta(_deltaFor(process).cpuDelta),
          _formatMemory(process.ram),
          _formatMemoryDelta(_deltaFor(process).memoryDeltaMb),
          process.isSystem ? 'System' : 'User',
          process.username ?? '',
          process.status ?? '',
        ].map(_csvCell).join(','),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) _toast('Visible process snapshot copied');
  }

  Future<void> _copyProcess(ProcessInfo process) async {
    final details = [
      'Process: ${process.name}',
      'PID: ${process.pid}',
      'CPU: ${process.cpu.toStringAsFixed(1)}%',
      'CPU change: ${_formatPercentDelta(_deltaFor(process).cpuDelta)}',
      'Memory: ${_formatMemory(process.ram)}',
      'Memory change: ${_formatMemoryDelta(_deltaFor(process).memoryDeltaMb)}',
      'Memory share: ${process.memoryPercent.toStringAsFixed(2)}%',
      'Type: ${process.isSystem ? 'System' : 'User'}',
      'User: ${process.username ?? 'Unavailable'}',
      'Status: ${process.status ?? 'Unavailable'}',
      'Threads: ${process.threadCount?.toString() ?? 'Unavailable'}',
      'Started: ${_formatStarted(process.startedAt)}',
    ];
    await Clipboard.setData(ClipboardData(text: details.join('\n')));
    if (mounted) _toast('${process.name} details copied');
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => searchQuery = '');
    _searchFocusNode.requestFocus();
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
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processes',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Triage active workloads, pin local watches, and capture process snapshots.',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 12,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusPill(
              label: loading
                  ? 'Refreshing'
                  : lastUpdated == null
                  ? 'Connecting'
                  : 'Updated ${_formatTime(lastUpdated!)}',
              color: error == null ? Colors.greenAccent : Colors.redAccent,
              busy: loading,
            ),
            Tooltip(
              message: 'Copy visible process snapshot  •  Ctrl/Command+Shift+C',
              child: IconButton(
                onPressed: filteredProcesses.isEmpty
                    ? null
                    : _copyVisibleProcesses,
                icon: const Icon(Icons.content_copy_rounded),
              ),
            ),
            Tooltip(
              message: 'Refresh processes  •  F5 / Ctrl/Command+R',
              child: IconButton(
                onPressed: loading ? null : () => loadProcesses(),
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 780) {
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

  Widget _buildSummaryCards(_ProcessSummary summary) {
    final cards = [
      _ProcessSummaryCard(
        label: 'Visible CPU',
        value: '${summary.visibleCpu.toStringAsFixed(1)}%',
        detail: 'Across current results',
        icon: Icons.speed_rounded,
        color: Colors.cyanAccent,
      ),
      _ProcessSummaryCard(
        label: 'Visible memory',
        value: _formatMemory(summary.visibleMemoryMb),
        detail: summary.topMemory == null
            ? 'No memory pressure'
            : 'Top: ${summary.topMemory!.name}',
        icon: Icons.memory_rounded,
        color: Colors.purpleAccent,
      ),
      _ProcessSummaryCard(
        label: 'Rising now',
        value: '${summary.risingCount}',
        detail: summary.topRising == null
            ? 'No recent spikes'
            : 'Top: ${summary.topRising!.name}',
        icon: Icons.trending_up_rounded,
        color: Colors.orangeAccent,
      ),
      _ProcessSummaryCard(
        label: 'Watched running',
        value: '${summary.watchedRunning}',
        detail: '${preferences.watchedProcessNames.length} names pinned',
        icon: Icons.star_rounded,
        color: Colors.amberAccent,
      ),
      _ProcessSummaryCard(
        label: 'Top CPU',
        value: summary.topCpu == null
            ? 'None'
            : '${summary.topCpu!.cpu.toStringAsFixed(1)}%',
        detail: summary.topCpu?.name ?? '${summary.systemHidden} system hidden',
        icon: Icons.trending_up_rounded,
        color: Colors.lightGreenAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search name, PID, or user...  Ctrl+F',
                hintStyle: TextStyle(color: AppColors.textMuted(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          if (searchQuery.trim().isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          Text(
            '${filteredProcesses.length} / ${processes.length}',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final filter in ProcessQuickFilter.values)
            Tooltip(
              message: filter.description,
              child: ChoiceChip(
                label: Text(filter.label),
                selected: preferences.quickFilter == filter,
                onSelected: (_) => _setQuickFilter(filter),
                avatar: Icon(_filterIcon(filter), size: 15),
                visualDensity: VisualDensity.compact,
              ),
            ),
          PopupMenuButton<ProcessSort>(
            tooltip: 'Sort processes',
            initialValue: preferences.sort,
            onSelected: _setSort,
            itemBuilder: (context) => [
              for (final sort in ProcessSort.values)
                PopupMenuItem(
                  value: sort,
                  child: Text('Sort by ${sort.label}'),
                ),
            ],
            child: _ControlChip(
              icon: Icons.sort_rounded,
              label: 'Sort: ${preferences.sort.label}',
            ),
          ),
          _ToggleChip(
            icon: Icons.shield_outlined,
            label: 'Hide system',
            value: preferences.hideSystemProcesses,
            onChanged: _setHideSystemProcesses,
          ),
          _ToggleChip(
            icon: Icons.autorenew_rounded,
            label: 'Auto refresh',
            value: preferences.autoRefresh,
            onChanged: _setAutoRefresh,
          ),
          _ToggleChip(
            icon: Icons.density_small_rounded,
            label: 'Compact rows',
            value: preferences.compactDensity,
            onChanged: _setCompactDensity,
          ),
          if (preferences.watchedProcessNames.isNotEmpty)
            TextButton.icon(
              onPressed: _clearWatched,
              icon: const Icon(Icons.playlist_remove_rounded, size: 16),
              label: const Text('Clear watchlist'),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessList(List<ProcessInfo> visible) {
    if (loading && processes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return _ProcessEmptyState(
        hasSearch: searchQuery.trim().isNotEmpty,
        quickFilter: preferences.quickFilter,
        onClearSearch: _clearSearch,
        onShowAll: () => _setQuickFilter(ProcessQuickFilter.all),
      );
    }

    final maxRam = visible.fold<double>(0, (maxValue, process) {
      return math.max(maxValue, process.ram);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactTable = constraints.maxWidth < 900;
        final listPadding = EdgeInsets.symmetric(
          vertical: preferences.compactDensity ? 4 : 8,
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: [
              if (!compactTable) ...[
                const _ProcessTableHeader(),
                Divider(height: 1, color: AppColors.border(context)),
              ],
              Expanded(
                child: ListView.separated(
                  padding: listPadding,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: preferences.compactDensity ? 1 : 2),
                  itemBuilder: (context, index) {
                    final process = visible[index];
                    return _ProcessTile(
                      process: process,
                      delta: _deltaFor(process),
                      watched: preferences.isWatched(process.name),
                      maxRam: maxRam,
                      compactDensity: preferences.compactDensity,
                      onKill: () => _confirmKill(process),
                      onToggleWatched: () => _toggleWatched(process),
                      onCopy: () => _copyProcess(process),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = filteredProcesses;
    final summary = _buildSummary(visible);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.f5): () => loadProcesses(),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            loadProcesses(),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            loadProcesses(),
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): _copyVisibleProcesses,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true):
            _copyVisibleProcesses,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _clearSearch,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _clearSearch,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : 720.0;
            final denseVertical = availableHeight < 820;
            final scrollPage =
                !constraints.hasBoundedHeight || availableHeight < 760;
            final pagePadding = denseVertical ? 16.0 : 24.0;
            final largeGap = denseVertical ? 10.0 : 16.0;
            final mediumGap = denseVertical ? 8.0 : 14.0;
            final minContentHeight = math.max(
              0.0,
              availableHeight - (pagePadding * 2),
            );
            final compactListHeight = math.max(300.0, availableHeight * 0.48);
            final leadingChildren = [
              _buildHeader(),
              SizedBox(height: largeGap),
              _buildSummaryCards(summary),
              SizedBox(height: mediumGap),
              _buildProcessControls(),
              SizedBox(height: mediumGap),
              _buildSearch(),
              if (!preferencesReady) ...[
                SizedBox(height: denseVertical ? 6 : 10),
                _InlineNotice(
                  icon: Icons.settings_rounded,
                  message: 'Loading saved process preferences...',
                  color: Colors.cyanAccent,
                ),
              ],
              if (error != null) ...[
                SizedBox(height: denseVertical ? 6 : 10),
                _InlineNotice(
                  icon: Icons.cloud_off_rounded,
                  message:
                      'Process telemetry is unavailable. HardwareMon will retry the local backend.',
                  color: Colors.redAccent,
                ),
              ],
              SizedBox(height: largeGap),
            ];

            if (scrollPage) {
              return Padding(
                padding: EdgeInsets.all(pagePadding),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...leadingChildren,
                        SizedBox(
                          height: compactListHeight,
                          child: _buildProcessList(visible),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...leadingChildren,
                  Expanded(child: _buildProcessList(visible)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProcessSummary {
  final double visibleCpu;
  final double visibleMemoryMb;
  final int watchedRunning;
  final int systemHidden;
  final int risingCount;
  final ProcessInfo? topCpu;
  final ProcessInfo? topMemory;
  final ProcessInfo? topRising;

  const _ProcessSummary({
    required this.visibleCpu,
    required this.visibleMemoryMb,
    required this.watchedRunning,
    required this.systemHidden,
    required this.risingCount,
    required this.topCpu,
    required this.topMemory,
    required this.topRising,
  });
}

class _ProcessDelta {
  final double cpuDelta;
  final double memoryDeltaMb;

  const _ProcessDelta({this.cpuDelta = 0, this.memoryDeltaMb = 0});
}

class _ProcessSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _ProcessSummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
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
      ),
    );
  }
}

class _ProcessTableHeader extends StatelessWidget {
  const _ProcessTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            flex: 4,
            child: Text('Process', style: _headerStyle(context)),
          ),
          SizedBox(width: 84, child: Text('PID', style: _headerStyle(context))),
          SizedBox(
            width: 128,
            child: Text('CPU', style: _headerStyle(context)),
          ),
          SizedBox(
            width: 150,
            child: Text('Memory', style: _headerStyle(context)),
          ),
          const SizedBox(width: 92),
        ],
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return TextStyle(
      color: AppColors.textMuted(context),
      fontSize: 9,
      fontWeight: FontWeight.w800,
    );
  }
}

class _ProcessTile extends StatefulWidget {
  final ProcessInfo process;
  final _ProcessDelta delta;
  final bool watched;
  final double maxRam;
  final bool compactDensity;
  final VoidCallback onKill;
  final VoidCallback onToggleWatched;
  final VoidCallback onCopy;

  const _ProcessTile({
    required this.process,
    required this.delta,
    required this.watched,
    required this.maxRam,
    required this.compactDensity,
    required this.onKill,
    required this.onToggleWatched,
    required this.onCopy,
  });

  @override
  State<_ProcessTile> createState() => _ProcessTileState();
}

class _ProcessTileState extends State<_ProcessTile> {
  bool expanded = false;
  bool hovering = false;
  bool focused = false;

  Future<void> _showContextMenu(TapDownDetails details) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'watch',
          child: Text(widget.watched ? 'Remove watch' : 'Watch process name'),
        ),
        const PopupMenuItem(value: 'copy', child: Text('Copy process details')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'end', child: Text('End process')),
      ],
    );

    if (action == 'watch') widget.onToggleWatched();
    if (action == 'copy') widget.onCopy();
    if (action == 'end') widget.onKill();
  }

  @override
  Widget build(BuildContext context) {
    final process = widget.process;
    final delta = widget.delta;
    final watchedColor = widget.watched ? Colors.amberAccent : null;
    final ramRatio = widget.maxRam <= 0 ? 0.0 : process.ram / widget.maxRam;
    final outerMargin = EdgeInsets.symmetric(
      horizontal: widget.compactDensity ? 6 : 10,
      vertical: widget.compactDensity ? 2 : 4,
    );
    final compactPadding = EdgeInsets.all(widget.compactDensity ? 10 : 14);
    final desktopPadding = EdgeInsets.fromLTRB(
      10,
      widget.compactDensity ? 8 : 12,
      10,
      widget.compactDensity ? 8 : 12,
    );

    return Semantics(
      container: true,
      label:
          '${process.name}, PID ${process.pid}, CPU ${process.cpu.toStringAsFixed(1)} percent, memory ${_formatMemory(process.ram)}, ${process.isSystem ? 'system process' : 'user process'}.',
      child: GestureDetector(
        onSecondaryTapDown: _showContextMenu,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                setState(() => expanded = !expanded);
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => hovering = true),
            onExit: (_) => setState(() => hovering = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: outerMargin,
              decoration: BoxDecoration(
                color: widget.watched
                    ? Colors.amberAccent.withValues(alpha: 0.055)
                    : hovering
                    ? AppColors.overlay(context, 0.045)
                    : AppColors.overlay(context, 0.025),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.watched
                      ? Colors.amberAccent.withValues(alpha: 0.2)
                      : focused
                      ? AppColors.accent.withValues(alpha: 0.42)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 900;
                      if (compact) {
                        return Padding(
                          padding: compactPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProcessIdentity(
                                process: process,
                                watched: widget.watched,
                                onToggleWatched: widget.onToggleWatched,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _InlineDetail(
                                    label: 'PID',
                                    value: '${process.pid}',
                                  ),
                                  _UsageBar(
                                    label: 'CPU',
                                    value: '${process.cpu.toStringAsFixed(1)}%',
                                    delta: _formatPercentDelta(delta.cpuDelta),
                                    ratio: (process.cpu / 100).clamp(0, 1),
                                    color: Colors.cyanAccent,
                                    width: 140,
                                  ),
                                  _UsageBar(
                                    label: 'Memory',
                                    value: _formatMemory(process.ram),
                                    delta: _formatMemoryDelta(
                                      delta.memoryDeltaMb,
                                    ),
                                    ratio: ramRatio.clamp(0, 1),
                                    color: Colors.purpleAccent,
                                    width: 160,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _ProcessActions(
                                expanded: expanded,
                                onExpand: () =>
                                    setState(() => expanded = !expanded),
                                onCopy: widget.onCopy,
                                onKill: widget.onKill,
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: desktopPadding,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: IconButton(
                                tooltip: widget.watched
                                    ? 'Remove watch'
                                    : 'Watch process name',
                                onPressed: widget.onToggleWatched,
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  widget.watched
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: watchedColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: _ProcessIdentity(
                                process: process,
                                watched: widget.watched,
                                showWatchButton: false,
                                onToggleWatched: widget.onToggleWatched,
                              ),
                            ),
                            SizedBox(
                              width: 84,
                              child: Text(
                                '${process.pid}',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 128,
                              child: _UsageBar(
                                label: 'CPU',
                                value: '${process.cpu.toStringAsFixed(1)}%',
                                delta: _formatPercentDelta(delta.cpuDelta),
                                ratio: (process.cpu / 100).clamp(0, 1),
                                color: Colors.cyanAccent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 136,
                              child: _UsageBar(
                                label: 'RAM',
                                value: _formatMemory(process.ram),
                                delta: _formatMemoryDelta(delta.memoryDeltaMb),
                                ratio: ramRatio.clamp(0, 1),
                                color: Colors.purpleAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ProcessActions(
                              expanded: expanded,
                              onExpand: () =>
                                  setState(() => expanded = !expanded),
                              onCopy: widget.onCopy,
                              onKill: widget.onKill,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      reverseDuration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? _ProcessExpandedDetails(
                              process: process,
                              delta: delta,
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

class _ProcessIdentity extends StatelessWidget {
  final ProcessInfo process;
  final bool watched;
  final bool showWatchButton;
  final VoidCallback onToggleWatched;

  const _ProcessIdentity({
    required this.process,
    required this.watched,
    required this.onToggleWatched,
    this.showWatchButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showWatchButton) ...[
          IconButton(
            tooltip: watched ? 'Remove watch' : 'Watch process name',
            onPressed: onToggleWatched,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              watched ? Icons.star_rounded : Icons.star_border_rounded,
              color: watched
                  ? Colors.amberAccent
                  : AppColors.textMuted(context),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                process.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _ProcessBadge(
                    label: process.isSystem ? 'System' : 'User',
                    color: process.isSystem
                        ? Colors.blueGrey
                        : Colors.greenAccent,
                  ),
                  if (watched)
                    const _ProcessBadge(
                      label: 'Watched',
                      color: Colors.amberAccent,
                    ),
                  if (process.status != null)
                    _ProcessBadge(
                      label: process.status!,
                      color: Colors.cyanAccent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessActions extends StatelessWidget {
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCopy;
  final VoidCallback onKill;

  const _ProcessActions({
    required this.expanded,
    required this.onExpand,
    required this.onCopy,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Copy details',
          onPressed: onCopy,
          iconSize: 17,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.content_copy_rounded),
        ),
        IconButton(
          tooltip: expanded ? 'Hide details' : 'Show details',
          onPressed: onExpand,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded),
          ),
        ),
        IconButton(
          tooltip: 'End process',
          onPressed: onKill,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.close_rounded,
            color: Colors.redAccent.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _ProcessExpandedDetails extends StatelessWidget {
  final ProcessInfo process;
  final _ProcessDelta delta;

  const _ProcessExpandedDetails({required this.process, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 3 : 1;
          final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
          final details = [
            _InlineDetail(
              label: 'User',
              value: process.username ?? 'Unavailable',
            ),
            _InlineDetail(
              label: 'Started',
              value: _formatStarted(process.startedAt),
            ),
            _InlineDetail(
              label: 'Threads',
              value: process.threadCount?.toString() ?? 'Unavailable',
            ),
            _InlineDetail(
              label: 'Memory share',
              value: '${process.memoryPercent.toStringAsFixed(2)}%',
            ),
            _InlineDetail(
              label: 'CPU change',
              value: _formatPercentDelta(delta.cpuDelta),
            ),
            _InlineDetail(
              label: 'Memory change',
              value: _formatMemoryDelta(delta.memoryDeltaMb),
            ),
            _InlineDetail(
              label: 'Type',
              value: process.isSystem ? 'System service' : 'User workload',
            ),
            _InlineDetail(
              label: 'Status',
              value: process.status ?? 'Unavailable',
            ),
          ];

          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final detail in details)
                SizedBox(width: width, child: detail),
            ],
          );
        },
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final double ratio;
  final Color color;
  final double? width;

  const _UsageBar({
    required this.label,
    required this.value,
    this.delta,
    required this.ratio,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    delta == null || delta == '0' ? value : '$value  $delta',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 6,
            color: AppColors.overlay(context, 0.055),
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              widthFactor: ratio.clamp(0, 1),
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
    );

    return width == null ? content : SizedBox(width: width, child: content);
  }
}

class _InlineDetail extends StatelessWidget {
  final String label;
  final String value;

  const _InlineDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.028),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProcessBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ProcessBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ControlChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 3),
        decoration: BoxDecoration(
          color: value
              ? AppColors.accent.withValues(alpha: 0.09)
              : AppColors.overlay(context, 0.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.accent.withValues(alpha: 0.2)
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
                fontWeight: FontWeight.w700,
              ),
            ),
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool busy;

  const _StatusPill({
    required this.label,
    required this.color,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox.square(
              dimension: 9,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 10, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessEmptyState extends StatelessWidget {
  final bool hasSearch;
  final ProcessQuickFilter quickFilter;
  final VoidCallback onClearSearch;
  final VoidCallback onShowAll;

  const _ProcessEmptyState({
    required this.hasSearch,
    required this.quickFilter,
    required this.onClearSearch,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = quickFilter != ProcessQuickFilter.all;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : filtered
                  ? Icons.filter_alt_off_rounded
                  : Icons.hourglass_empty_rounded,
              size: 38,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? 'No matching processes'
                  : filtered
                  ? 'No processes in ${quickFilter.label}'
                  : 'No processes available',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try another name, PID, or user.'
                  : 'HardwareMon will keep checking the local backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (hasSearch)
                  OutlinedButton.icon(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear search'),
                  ),
                if (filtered)
                  OutlinedButton.icon(
                    onPressed: onShowAll,
                    icon: const Icon(Icons.filter_alt_rounded, size: 16),
                    label: const Text('Show all'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _filterIcon(ProcessQuickFilter filter) {
  return switch (filter) {
    ProcessQuickFilter.all => Icons.all_inclusive_rounded,
    ProcessQuickFilter.busy => Icons.local_fire_department_rounded,
    ProcessQuickFilter.rising => Icons.trending_up_rounded,
    ProcessQuickFilter.memory => Icons.memory_rounded,
    ProcessQuickFilter.watched => Icons.star_rounded,
  };
}

String _formatMemory(double megabytes) {
  if (megabytes >= 1024) {
    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }
  return '${megabytes.toStringAsFixed(1)} MB';
}

String _formatPercentDelta(double value) {
  if (value.abs() < 0.05) return '0';
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}%';
}

String _formatMemoryDelta(double megabytes) {
  if (megabytes.abs() < 0.5) return '0';
  final prefix = megabytes > 0 ? '+' : '';
  if (megabytes.abs() >= 1024) {
    return '$prefix${(megabytes / 1024).toStringAsFixed(2)} GB';
  }
  return '$prefix${megabytes.toStringAsFixed(0)} MB';
}

String _formatStarted(DateTime? startedAt) {
  if (startedAt == null) return 'Unavailable';
  final age = DateTime.now().difference(startedAt);
  if (age.inDays >= 1) return '${age.inDays}d ago';
  if (age.inHours >= 1) return '${age.inHours}h ago';
  if (age.inMinutes >= 1) return '${age.inMinutes}m ago';
  return 'Just now';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _csvCell(Object? value) {
  final text = (value ?? '').toString();
  final escaped = text.replaceAll('"', '""');
  return '"$escaped"';
}
