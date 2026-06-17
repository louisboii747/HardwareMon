import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/process_info.dart';
import '../../services/process_service.dart';
import '../../core/theme/app_colors.dart';

class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  List<ProcessInfo> processes = [];
  bool loading = true;
  String searchQuery = '';

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
    super.dispose();
  }

  List<ProcessInfo> get filteredProcesses {
    if (searchQuery.isEmpty) {
      return processes;
    }

    return processes.where((process) {
      return process.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    final mutedColor = AppColors.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Processes',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
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
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search processes...',
                      hintStyle: TextStyle(color: AppColors.textMuted(context)),
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
                          onKill: () async {
                            await ProcessService.killProcess(process.pid);

                            loadProcesses();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
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
    return Container(
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
    );
  }
}
