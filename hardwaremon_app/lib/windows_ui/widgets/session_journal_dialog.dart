import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/hardware_palette.dart';
import '../models/session_journal.dart';
import '../models/monitoring_lens.dart';

Future<void> showSessionJournalDialog({
  required BuildContext context,
  required SessionJournal journal,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SessionJournalDialog(journal: journal),
  );
}

class _SessionJournalDialog extends StatelessWidget {
  final SessionJournal journal;

  const _SessionJournalDialog({required this.journal});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.bookmarks_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session journal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Private snapshots saved only on this device.',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: journal,
                    builder: (context, _) => journal.entries.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            onPressed: () => _confirmClear(context),
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 16,
                            ),
                            label: const Text('Clear'),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedBuilder(
                  animation: journal,
                  builder: (context, _) {
                    if (journal.entries.isEmpty) {
                      return const _EmptyJournal();
                    }
                    return ListView.separated(
                      itemCount: journal.entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _JournalEntryCard(
                        entry: journal.entries[index],
                        onDelete: () =>
                            journal.remove(journal.entries[index].id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear session journal?'),
        content: const Text(
          'This removes every locally saved snapshot. Live telemetry and historical monitoring are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep snapshots'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear journal'),
          ),
        ],
      ),
    );
    if (confirmed == true) await journal.clear();
  }
}

class _JournalEntryCard extends StatelessWidget {
  final SessionJournalEntry entry;
  final VoidCallback onDelete;

  const _JournalEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = HardwareStatusColors.forScore(entry.score);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.score}',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
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
                      '${entry.stateLabel} · ${entry.lens.label}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat(
                        'EEE, d MMM · HH:mm:ss',
                      ).format(entry.capturedAt),
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy snapshot report',
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 17),
              ),
              IconButton(
                tooltip: 'Delete snapshot',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            entry.observation,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MetricPill(label: 'CPU', value: '${entry.cpuUsage}%'),
              _MetricPill(label: 'RAM', value: '${entry.ramUsage}%'),
              _MetricPill(label: 'GPU', value: '${entry.gpuUsage}%'),
              _MetricPill(
                label: 'Peak temp',
                value: entry.hottestTemperature <= 0
                    ? 'Unavailable'
                    : '${entry.hottestTemperature}°C',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: entry.report.trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session snapshot copied')));
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label  $value',
        style: TextStyle(
          color: AppColors.textMuted(context),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_add_outlined,
            size: 42,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(height: 12),
          const Text(
            'No session snapshots yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Capture a useful baseline, a heavy workload, or a thermal event from the dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
