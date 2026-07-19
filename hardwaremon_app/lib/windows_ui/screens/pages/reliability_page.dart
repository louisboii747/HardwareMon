import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/telemetry_sample.dart';
import '../../models/card_workspace.dart';
import '../../services/telemetry_service.dart';
import '../../widgets/card_workspace.dart';

class ReliabilityPage extends StatelessWidget {
  final TelemetryService telemetry;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenProcesses;
  final VoidCallback onOpenStorage;
  final VoidCallback onOpenNetwork;
  final CardWorkspacePreferences cardWorkspacePreferences;

  const ReliabilityPage({
    super.key,
    required this.telemetry,
    required this.onOpenPerformance,
    required this.onOpenProcesses,
    required this.onOpenStorage,
    required this.onOpenNetwork,
    required this.cardWorkspacePreferences,
  });

  Future<void> _copyBrief(
    BuildContext context,
    _ReliabilitySnapshot snapshot,
  ) async {
    final lines = [
      'HardwareMon Reliability Brief',
      'Captured: ${DateTime.now().toIso8601String()}',
      'Score: ${snapshot.score}/100 - ${snapshot.label}',
      'State: ${snapshot.detail}',
      'Session age: ${_formatDuration(snapshot.sessionAge)}',
      'Samples: ${snapshot.sampleCount}',
      '',
      'Signals:',
      for (final signal in snapshot.signals)
        '- ${signal.label}: ${signal.formattedValue} (${signal.status})',
      '',
      'Events:',
      for (final event in snapshot.events) '- ${event.title}: ${event.detail}',
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reliability brief copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _ReliabilitySnapshot.fromTelemetry(telemetry);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReliabilityHeader(
            snapshot: snapshot,
            onCopyBrief: () => _copyBrief(context, snapshot),
          ),
          const SizedBox(height: 16),
          _ReliabilityScorePanel(snapshot: snapshot),
          const SizedBox(height: 16),
          _SignalMatrix(
            signals: snapshot.signals,
            preferences: cardWorkspacePreferences,
          ),
          const SizedBox(height: 16),
          _ReliabilitySection(
            title: 'Live Incident Timeline',
            icon: Icons.emergency_share_rounded,
            child: _EventTimeline(events: snapshot.events),
          ),
          const SizedBox(height: 16),
          _ReliabilitySection(
            title: 'Session Drift',
            icon: Icons.troubleshoot_rounded,
            child: _DriftPanel(snapshot: snapshot),
          ),
          const SizedBox(height: 16),
          _ReliabilitySection(
            title: 'Recommended Next Actions',
            icon: Icons.route_rounded,
            child: _RunbookActions(
              snapshot: snapshot,
              onOpenPerformance: onOpenPerformance,
              onOpenProcesses: onOpenProcesses,
              onOpenStorage: onOpenStorage,
              onOpenNetwork: onOpenNetwork,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityHeader extends StatelessWidget {
  final _ReliabilitySnapshot snapshot;
  final VoidCallback onCopyBrief;

  const _ReliabilityHeader({required this.snapshot, required this.onCopyBrief});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reliability',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Stability score, active risks, drift, and recovery actions in one place.',
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
            _ReliabilityPill(
              label: snapshot.label,
              icon: Icons.verified_rounded,
              color: snapshot.color,
            ),
            OutlinedButton.icon(
              onPressed: onCopyBrief,
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Copy brief'),
            ),
          ],
        );

        if (compact) {
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
}

class _ReliabilityScorePanel extends StatelessWidget {
  final _ReliabilitySnapshot snapshot;

  const _ReliabilityScorePanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Reliability score ${snapshot.score} out of 100. ${snapshot.detail}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: snapshot.color.withValues(alpha: 0.06),
              blurRadius: 28,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final score = Row(
              children: [
                _ScoreDial(score: snapshot.score, color: snapshot.color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.detail,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final facts = _ReliabilityFacts(snapshot: snapshot);

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [score, const SizedBox(height: 16), facts],
              );
            }
            return Row(
              children: [
                Expanded(flex: 4, child: score),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: facts),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreDial({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: AppColors.overlay(context, 0.06),
          ),
          Text(
            '$score',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityFacts extends StatelessWidget {
  final _ReliabilitySnapshot snapshot;

  const _ReliabilityFacts({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final facts = [
      _Fact(
        label: 'Session age',
        value: _formatDuration(snapshot.sessionAge),
        icon: Icons.timer_rounded,
        color: Colors.lightBlueAccent,
      ),
      _Fact(
        label: 'Active events',
        value: '${snapshot.activeEventCount}',
        icon: Icons.warning_amber_rounded,
        color: snapshot.activeEventCount == 0
            ? Colors.greenAccent
            : Colors.orangeAccent,
      ),
      _Fact(
        label: 'Peak pressure',
        value: '${snapshot.peakPressure.round()}%',
        icon: Icons.speed_rounded,
        color: _valueColor(snapshot.peakPressure),
      ),
      _Fact(
        label: 'Thermal margin',
        value: '${snapshot.thermalMargin.round()}°C',
        icon: Icons.device_thermostat_rounded,
        color: snapshot.thermalMargin <= 8
            ? Colors.redAccent
            : snapshot.thermalMargin <= 16
            ? Colors.orangeAccent
            : Colors.greenAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 540 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final fact in facts)
              SizedBox(
                width: width,
                child: _FactTile(fact: fact),
              ),
          ],
        );
      },
    );
  }
}

class _SignalMatrix extends StatelessWidget {
  final List<_ReliabilitySignal> signals;
  final CardWorkspacePreferences preferences;

  const _SignalMatrix({required this.signals, required this.preferences});

  @override
  Widget build(BuildContext context) {
    return CardWorkspace(
      pageId: 'reliability-signals',
      pageLabel: 'Reliability signals',
      preferences: preferences,
      standardHeight: 150,
      cards: [
        for (final signal in signals)
          WorkspaceCard(
            id: signal.label.toLowerCase().replaceAll(' ', '-'),
            title: signal.label,
            child: _SignalCard(signal: signal),
          ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  final _ReliabilitySignal signal;

  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final fill = (signal.value / signal.limit).clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: '${signal.label}, ${signal.formattedValue}, ${signal.status}',
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: signal.color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: signal.color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: signal.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(signal.icon, color: signal.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.formattedValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signal.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _ReliabilityPill(
                  label: signal.status,
                  icon: Icons.circle_rounded,
                  color: signal.color,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 8,
                color: AppColors.overlay(context, 0.055),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          signal.color.withValues(alpha: 0.55),
                          signal.color,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReliabilitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ReliabilitySection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.accent),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<_ReliabilityEvent> events;

  const _EventTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < events.length; index++) ...[
          _EventTile(event: events[index]),
          if (index != events.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final _ReliabilityEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${event.title}. ${event.detail}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: event.color.withValues(alpha: 0.18)),
            ),
            child: Icon(event.icon, color: event.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.detail,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 11,
                    height: 1.35,
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

class _DriftPanel extends StatelessWidget {
  final _ReliabilitySnapshot snapshot;

  const _DriftPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final rows = [
          _DriftRow(
            label: 'CPU vs session average',
            current: snapshot.cpuCurrent,
            average: snapshot.cpuAverage,
            unit: '%',
            color: Colors.cyanAccent,
          ),
          _DriftRow(
            label: 'Memory vs session average',
            current: snapshot.ramCurrent,
            average: snapshot.ramAverage,
            unit: '%',
            color: Colors.purpleAccent,
          ),
          _DriftRow(
            label: 'GPU vs session average',
            current: snapshot.gpuCurrent,
            average: snapshot.gpuAverage,
            unit: '%',
            color: Colors.orangeAccent,
          ),
          _DriftRow(
            label: 'CPU thermal drift',
            current: snapshot.cpuTempCurrent,
            average: snapshot.cpuTempAverage,
            unit: '°C',
            color: Colors.redAccent,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                rows[index],
                if (index != rows.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final row in rows)
              SizedBox(width: (constraints.maxWidth - 10) / 2, child: row),
          ],
        );
      },
    );
  }
}

class _DriftRow extends StatelessWidget {
  final String label;
  final double current;
  final double average;
  final String unit;
  final Color color;

  const _DriftRow({
    required this.label,
    required this.current,
    required this.average,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final delta = current - average;
    final deltaColor = delta.abs() <= 4
        ? Colors.greenAccent
        : delta > 0
        ? Colors.orangeAccent
        : Colors.lightBlueAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Now ${current.toStringAsFixed(0)}$unit · Avg ${average.toStringAsFixed(0)}$unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ReliabilityPill(
            label: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}$unit',
            icon: delta >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: deltaColor,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _RunbookActions extends StatelessWidget {
  final _ReliabilitySnapshot snapshot;
  final VoidCallback onOpenPerformance;
  final VoidCallback onOpenProcesses;
  final VoidCallback onOpenStorage;
  final VoidCallback onOpenNetwork;

  const _RunbookActions({
    required this.snapshot,
    required this.onOpenPerformance,
    required this.onOpenProcesses,
    required this.onOpenStorage,
    required this.onOpenNetwork,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (snapshot.cpuCurrent >= 80 || snapshot.ramCurrent >= 80)
        _RunbookAction(
          label: 'Inspect top workloads',
          detail: 'Find the process creating pressure.',
          icon: Icons.list_rounded,
          color: Colors.cyanAccent,
          onPressed: onOpenProcesses,
        ),
      if (snapshot.cpuTempCurrent >= 78 || snapshot.gpuTempCurrent >= 76)
        _RunbookAction(
          label: 'Review thermals',
          detail: 'Open trends and cooling headroom.',
          icon: Icons.device_thermostat_rounded,
          color: Colors.orangeAccent,
          onPressed: onOpenPerformance,
        ),
      if (snapshot.diskCurrent >= 80)
        _RunbookAction(
          label: 'Free storage headroom',
          detail: 'Check drive capacity and cleanup targets.',
          icon: Icons.storage_rounded,
          color: Colors.purpleAccent,
          onPressed: onOpenStorage,
        ),
      if (snapshot.hasTelemetryIssue)
        _RunbookAction(
          label: 'Check telemetry path',
          detail: 'Open network tools and local status.',
          icon: Icons.language_rounded,
          color: Colors.redAccent,
          onPressed: onOpenNetwork,
        ),
      _RunbookAction(
        label: 'Open performance evidence',
        detail: 'Compare current risk against live charts.',
        icon: Icons.analytics_rounded,
        color: Colors.lightGreenAccent,
        onPressed: onOpenPerformance,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final action in actions) _RunbookButton(action: action)],
    );
  }
}

class _RunbookButton extends StatelessWidget {
  final _RunbookAction action;

  const _RunbookButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: OutlinedButton(
        onPressed: action.onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(12),
          side: BorderSide(color: action.color.withValues(alpha: 0.28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Icon(action.icon, color: action.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 10,
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

class _FactTile extends StatelessWidget {
  final _Fact fact;

  const _FactTile({required this.fact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fact.color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fact.color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(fact.icon, color: fact.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fact.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 10,
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

class _ReliabilityPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool compact;

  const _ReliabilityPill({
    required this.label,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 11 : 15),
          SizedBox(width: compact ? 5 : 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilitySnapshot {
  final int score;
  final String label;
  final String detail;
  final Color color;
  final List<_ReliabilitySignal> signals;
  final List<_ReliabilityEvent> events;
  final Duration sessionAge;
  final int sampleCount;
  final double peakPressure;
  final double thermalMargin;
  final double cpuCurrent;
  final double ramCurrent;
  final double gpuCurrent;
  final double diskCurrent;
  final double cpuTempCurrent;
  final double gpuTempCurrent;
  final double cpuAverage;
  final double ramAverage;
  final double gpuAverage;
  final double cpuTempAverage;
  final bool hasTelemetryIssue;

  const _ReliabilitySnapshot({
    required this.score,
    required this.label,
    required this.detail,
    required this.color,
    required this.signals,
    required this.events,
    required this.sessionAge,
    required this.sampleCount,
    required this.peakPressure,
    required this.thermalMargin,
    required this.cpuCurrent,
    required this.ramCurrent,
    required this.gpuCurrent,
    required this.diskCurrent,
    required this.cpuTempCurrent,
    required this.gpuTempCurrent,
    required this.cpuAverage,
    required this.ramAverage,
    required this.gpuAverage,
    required this.cpuTempAverage,
    required this.hasTelemetryIssue,
  });

  int get activeEventCount {
    return events
        .where((event) => event.severity != _ReliabilitySeverity.good)
        .length;
  }

  factory _ReliabilitySnapshot.fromTelemetry(TelemetryService telemetry) {
    final cpu = telemetry.cpuUsage.toDouble();
    final ram = telemetry.ramUsage.toDouble();
    final gpu = telemetry.gpuUsage.toDouble();
    final disk = telemetry.diskUsage.toDouble();
    final cpuTemp = telemetry.cpuTemp.toDouble();
    final gpuTemp = telemetry.gpuTemp.toDouble();
    final peakPressure = [cpu, ram, gpu, disk].reduce(math.max);
    final thermalMargin = math.min(95 - cpuTemp, 90 - gpuTemp).clamp(0, 95);
    final events = <_ReliabilityEvent>[];
    var penalty = 0;

    void addEvent(
      _ReliabilitySeverity severity,
      String title,
      String detail,
      IconData icon, {
      required int cost,
    }) {
      events.add(
        _ReliabilityEvent(
          severity: severity,
          title: title,
          detail: detail,
          icon: icon,
          color: _severityColor(severity),
        ),
      );
      penalty += cost;
    }

    if (telemetry.lastError != null) {
      addEvent(
        _ReliabilitySeverity.critical,
        'Telemetry interrupted',
        'The local backend reported ${telemetry.lastError}.',
        Icons.cloud_off_rounded,
        cost: 26,
      );
    }

    final staleFor = telemetry.lastUpdated == null
        ? null
        : DateTime.now().difference(telemetry.lastUpdated!);
    if (staleFor != null && staleFor.inSeconds > 10) {
      addEvent(
        _ReliabilitySeverity.warning,
        'Telemetry is stale',
        'Last successful sample was ${_formatDuration(staleFor)} ago.',
        Icons.hourglass_bottom_rounded,
        cost: 10,
      );
    }

    if (telemetry.isPaused) {
      addEvent(
        _ReliabilitySeverity.info,
        'Collection paused',
        'Live values are frozen until telemetry resumes.',
        Icons.pause_circle_outline_rounded,
        cost: 4,
      );
    }

    if (cpu >= 90) {
      addEvent(
        _ReliabilitySeverity.critical,
        'CPU saturation',
        'CPU is at ${cpu.toStringAsFixed(0)}%; foreground responsiveness may degrade.',
        Icons.memory_rounded,
        cost: 18,
      );
    } else if (cpu >= 75) {
      addEvent(
        _ReliabilitySeverity.warning,
        'CPU pressure building',
        'CPU is above the watch threshold at ${cpu.toStringAsFixed(0)}%.',
        Icons.memory_rounded,
        cost: 9,
      );
    }

    if (ram >= 90) {
      addEvent(
        _ReliabilitySeverity.critical,
        'Memory ceiling reached',
        'Memory is ${ram.toStringAsFixed(0)}%; paging risk is high.',
        Icons.storage_rounded,
        cost: 18,
      );
    } else if (ram >= 78) {
      addEvent(
        _ReliabilitySeverity.warning,
        'Memory watch',
        'Memory is ${ram.toStringAsFixed(0)}%; watch background workloads.',
        Icons.storage_rounded,
        cost: 8,
      );
    }

    if (disk >= 90) {
      addEvent(
        _ReliabilitySeverity.warning,
        'Disk headroom low',
        'Disk usage is ${disk.toStringAsFixed(0)}%; update and cache writes may struggle.',
        Icons.inventory_2_rounded,
        cost: 10,
      );
    }

    if (cpuTemp >= 90 || gpuTemp >= 86) {
      addEvent(
        _ReliabilitySeverity.critical,
        'Thermal limit close',
        'CPU ${cpuTemp.toStringAsFixed(0)}°C, GPU ${gpuTemp.toStringAsFixed(0)}°C.',
        Icons.device_thermostat_rounded,
        cost: 22,
      );
    } else if (cpuTemp >= 80 || gpuTemp >= 78) {
      addEvent(
        _ReliabilitySeverity.warning,
        'Thermal margin narrowing',
        'Cooling headroom is down to ${thermalMargin.toStringAsFixed(0)}°C.',
        Icons.device_thermostat_rounded,
        cost: 11,
      );
    }

    if (events.isEmpty) {
      events.add(
        const _ReliabilityEvent(
          severity: _ReliabilitySeverity.good,
          title: 'No active incidents',
          detail: 'Current telemetry is inside the reliability envelope.',
          icon: Icons.check_circle_outline_rounded,
          color: Colors.greenAccent,
        ),
      );
    }

    final score = (100 - penalty).clamp(0, 100).toInt();
    final label = score >= 90
        ? 'Operational'
        : score >= 75
        ? 'Stable'
        : score >= 55
        ? 'Watch'
        : 'At risk';
    final color = score >= 90
        ? Colors.greenAccent
        : score >= 75
        ? Colors.cyanAccent
        : score >= 55
        ? Colors.orangeAccent
        : Colors.redAccent;
    final detail = score >= 90
        ? 'No active reliability concerns detected.'
        : score >= 75
        ? 'A few signals deserve attention, but the system is holding steady.'
        : score >= 55
        ? 'Reliability is trending toward intervention territory.'
        : 'Immediate triage is recommended before pressure cascades.';

    final signals = [
      _ReliabilitySignal.percent('CPU load', cpu, Icons.memory_rounded),
      _ReliabilitySignal.percent('Memory load', ram, Icons.storage_rounded),
      _ReliabilitySignal.percent('GPU load', gpu, Icons.graphic_eq_rounded),
      _ReliabilitySignal.percent('Disk usage', disk, Icons.inventory_2_rounded),
      _ReliabilitySignal.temperature(
        'CPU thermals',
        cpuTemp,
        Icons.thermostat_rounded,
      ),
      _ReliabilitySignal.temperature(
        'GPU thermals',
        gpuTemp,
        Icons.device_thermostat_rounded,
      ),
    ];

    return _ReliabilitySnapshot(
      score: score,
      label: label,
      detail: detail,
      color: color,
      signals: signals,
      events: events,
      sessionAge: DateTime.now().difference(
        telemetry.sessionStatisticsStartedAt,
      ),
      sampleCount:
          telemetry.cpuHistory.length +
          telemetry.ramHistory.length +
          telemetry.gpuUsageHistory.length,
      peakPressure: peakPressure,
      thermalMargin: thermalMargin.toDouble(),
      cpuCurrent: cpu,
      ramCurrent: ram,
      gpuCurrent: gpu,
      diskCurrent: disk,
      cpuTempCurrent: cpuTemp,
      gpuTempCurrent: gpuTemp,
      cpuAverage: _averageOr(telemetry.cpuHistory, cpu),
      ramAverage: _averageOr(telemetry.ramHistory, ram),
      gpuAverage: _averageOr(telemetry.gpuUsageHistory, gpu),
      cpuTempAverage: _averageOr(telemetry.cpuTempHistory, cpuTemp),
      hasTelemetryIssue: telemetry.lastError != null || staleFor != null,
    );
  }
}

class _ReliabilitySignal {
  final String label;
  final double value;
  final double limit;
  final String unit;
  final IconData icon;
  final Color color;
  final String status;

  const _ReliabilitySignal({
    required this.label,
    required this.value,
    required this.limit,
    required this.unit,
    required this.icon,
    required this.color,
    required this.status,
  });

  factory _ReliabilitySignal.percent(
    String label,
    double value,
    IconData icon,
  ) {
    return _ReliabilitySignal(
      label: label,
      value: value,
      limit: 100,
      unit: '%',
      icon: icon,
      color: _valueColor(value),
      status: _statusFor(value),
    );
  }

  factory _ReliabilitySignal.temperature(
    String label,
    double value,
    IconData icon,
  ) {
    return _ReliabilitySignal(
      label: label,
      value: value,
      limit: 100,
      unit: '°C',
      icon: icon,
      color: value >= 88
          ? Colors.redAccent
          : value >= 78
          ? Colors.orangeAccent
          : Colors.greenAccent,
      status: value >= 88
          ? 'Critical'
          : value >= 78
          ? 'Watch'
          : 'Clear',
    );
  }

  String get formattedValue => '${value.toStringAsFixed(0)}$unit';
}

class _ReliabilityEvent {
  final _ReliabilitySeverity severity;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _ReliabilityEvent({
    required this.severity,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _Fact {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Fact({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _RunbookAction {
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RunbookAction({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}

enum _ReliabilitySeverity { good, info, warning, critical }

Color _severityColor(_ReliabilitySeverity severity) {
  return switch (severity) {
    _ReliabilitySeverity.good => Colors.greenAccent,
    _ReliabilitySeverity.info => Colors.cyanAccent,
    _ReliabilitySeverity.warning => Colors.orangeAccent,
    _ReliabilitySeverity.critical => Colors.redAccent,
  };
}

Color _valueColor(double value) {
  if (value >= 90) {
    return Colors.redAccent;
  }
  if (value >= 75) {
    return Colors.orangeAccent;
  }
  return Colors.greenAccent;
}

String _statusFor(double value) {
  if (value >= 90) {
    return 'Critical';
  }
  if (value >= 75) {
    return 'Watch';
  }
  return 'Clear';
}

double _averageOr(List<TelemetrySample> samples, double fallback) {
  if (samples.isEmpty) return fallback;
  final total = samples.fold<double>(0, (sum, sample) => sum + sample.value);
  return total / samples.length;
}

String _formatDuration(Duration duration) {
  if (duration.inDays >= 1) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  }
  if (duration.inHours >= 1) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes >= 1) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds.clamp(0, 59)}s';
}
