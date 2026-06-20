import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/process_info.dart';
import '../../services/process_service.dart';
import '../../core/theme/app_colors.dart';

enum _ProcessSort { cpu, memory, name }

class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  List<ProcessInfo> processes = [];
  bool loading = true;
  bool hideSystemProcesses = true;
  String searchQuery = '';
  _ProcessSort sort = _ProcessSort.cpu;
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'Process search');
  final TextEditingController _searchController = TextEditingController();

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();

    loadProcesses();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => loadProcesses(),
    );
  }

  Future<void> loadProcesses() async {
    try {
      final data = await ProcessService.fetchProcesses();

      if (!mounted) return;

      setState(() {
        processes = data;
        loading = false;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ProcessInfo> get filteredProcesses {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    final filtered = processes.where((process) {
      final matchesProcessType = !hideSystemProcesses || !process.isSystem;
      final matchesSearch =
          normalizedQuery.isEmpty ||
          process.name.toLowerCase().contains(normalizedQuery) ||
          process.pid.toString().contains(normalizedQuery);

      return matchesProcessType && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      return switch (sort) {
        _ProcessSort.cpu => b.cpu.compareTo(a.cpu),
        _ProcessSort.memory => b.ram.compareTo(a.ram),
        _ProcessSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      };
    });
    return filtered;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('End request sent for ${process.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProcessControls(BuildContext context, Color mutedColor) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<_ProcessSort>(
          tooltip: 'Sort processes',
          initialValue: sort,
          onSelected: (value) => setState(() => sort = value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ProcessSort.cpu, child: Text('Sort by CPU')),
            PopupMenuItem(
              value: _ProcessSort.memory,
              child: Text('Sort by memory'),
            ),
            PopupMenuItem(
              value: _ProcessSort.name,
              child: Text('Sort by name'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.overlay(context, 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  switch (sort) {
                    _ProcessSort.cpu => 'CPU',
                    _ProcessSort.memory => 'Memory',
                    _ProcessSort.name => 'Name',
                  },
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 18,
              color: hideSystemProcesses
                  ? Theme.of(context).colorScheme.primary
                  : mutedColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Hide system processes',
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Show user applications such as browsers, editors, and file managers',
              child: Switch(
                value: hideSystemProcesses,
                onChanged: (value) =>
                    setState(() => hideSystemProcesses = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    final mutedColor = AppColors.textSecondary(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocusNode.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final controls = _buildProcessControls(context, mutedColor);
                  if (constraints.maxWidth < 700) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Processes',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        controls,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Text(
                        'Processes',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      controls,
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border(context)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: mutedColor),

                    const SizedBox(width: 12),

                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search by name or PID…  Ctrl+F',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted(context),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    Text(
                      '${filteredProcesses.length} processes',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredProcesses.isEmpty
                    ? _ProcessEmptyState(
                        hasSearch: searchQuery.trim().isNotEmpty,
                        onClear: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: ListView.builder(
                          itemCount: filteredProcesses.length,
                          itemBuilder: (context, index) {
                            final process = filteredProcesses[index];

                            return _ProcessTile(
                              process: process,
                              onKill: () => _confirmKill(process),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessTile extends StatelessWidget {
  final ProcessInfo process;
  final VoidCallback? onKill;

  const _ProcessTile({required this.process, required this.onKill});

  @override
  Widget build(BuildContext context) {
    Future<void> copyText(String label, String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    Future<void> showContextMenu(TapDownDetails details) async {
      final action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.globalPosition.dx,
          details.globalPosition.dy,
        ),
        items: const [
          PopupMenuItem(value: 'name', child: Text('Copy process name')),
          PopupMenuItem(value: 'pid', child: Text('Copy PID')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'end', child: Text('End process')),
        ],
      );
      if (action == 'name') await copyText('Process name', process.name);
      if (action == 'pid') await copyText('PID', process.pid.toString());
      if (action == 'end') onKill?.call();
    }

    return GestureDetector(
      onSecondaryTapDown: showContextMenu,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.overlay(context, 0.03),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                process.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            Expanded(
              child: Text(
                'PID ${process.pid}',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),

            Expanded(child: Text('${process.cpu.toStringAsFixed(1)}%')),

            Expanded(child: Text('${process.ram.toStringAsFixed(1)} MB')),

            IconButton(
              onPressed: onKill,
              icon: Icon(
                Icons.close_rounded,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessEmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClear;

  const _ProcessEmptyState({required this.hasSearch, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.hourglass_empty_rounded,
            size: 38,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No matching processes' : 'No processes available',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}
