import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../models/network_models.dart';
import '../models/telemetry_sample.dart';
import '../widgets/glass_panel.dart';

class NetworkFocusScreen extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<TelemetrySample> primarySamples;
  final List<TelemetrySample> secondarySamples;
  final String primaryLabel;
  final String secondaryLabel;
  final NetworkInterfaceInfo? interfaceInfo;
  final NetworkSnapshot? snapshot;

  const NetworkFocusScreen({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.primarySamples = const [],
    this.secondarySamples = const [],
    this.primaryLabel = 'Download',
    this.secondaryLabel = 'Upload',
    this.interfaceInfo,
    this.snapshot,
  });

  Future<void> _copySummary(BuildContext context) async {
    final adapter = interfaceInfo;
    final summary = [
      'HardwareMon Network Analytics',
      '$title: $value',
      subtitle,
      if (adapter != null) ...[
        'Adapter: ${adapter.displayName}',
        'IPv4: ${adapter.ipv4 ?? 'Unavailable'}',
        'IPv6: ${adapter.ipv6 ?? 'Unavailable'}',
        'MAC: ${adapter.macAddress ?? 'Unavailable'}',
      ],
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Network analytics copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    accent,
                    0.05,
                  )!,
                  AppColors.backgroundTertiary(context),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to Network',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NETWORK FOCUS',
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Copy analytics',
                          onPressed: () => _copySummary(context),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NetworkFocusHero(
                            title: title,
                            value: value,
                            subtitle: subtitle,
                            icon: icon,
                            accent: accent,
                            interfaceInfo: interfaceInfo,
                          ),
                          const SizedBox(height: 20),
                          _NetworkFocusChart(
                            primarySamples: primarySamples,
                            secondarySamples: secondarySamples,
                            primaryLabel: primaryLabel,
                            secondaryLabel: secondaryLabel,
                            accent: accent,
                          ),
                          if (interfaceInfo != null) ...[
                            const SizedBox(height: 20),
                            _AdapterAnalytics(
                              interface: interfaceInfo!,
                              snapshot: snapshot,
                            ),
                          ],
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
}

class _NetworkFocusHero extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final NetworkInterfaceInfo? interfaceInfo;

  const _NetworkFocusHero({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.interfaceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.08), AppColors.surface(context)],
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 42),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final badge = Container(
            width: compact ? 58 : 72,
            height: compact ? 58 : 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accent, size: compact ? 27 : 33),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 34 : 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 11,
                ),
              ),
              if (interfaceInfo != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FocusPill(
                      icon: Icons.settings_ethernet_rounded,
                      label: interfaceInfo!.displayName,
                      color: accent,
                    ),
                    _FocusPill(
                      icon: Icons.lan_outlined,
                      label:
                          interfaceInfo!.ipv4 ??
                          interfaceInfo!.ipv6 ??
                          'IP unavailable',
                    ),
                    _FocusPill(
                      icon: interfaceInfo!.isUp
                          ? Icons.check_circle_outline_rounded
                          : Icons.portable_wifi_off_rounded,
                      label: interfaceInfo!.isUp ? 'Link active' : 'Link down',
                      color: interfaceInfo!.isUp
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [badge, const SizedBox(height: 16), content],
            );
          }
          return Row(
            children: [
              badge,
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkFocusChart extends StatelessWidget {
  final List<TelemetrySample> primarySamples;
  final List<TelemetrySample> secondarySamples;
  final String primaryLabel;
  final String secondaryLabel;
  final Color accent;

  const _NetworkFocusChart({
    required this.primarySamples,
    required this.secondarySamples,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final allValues = [
      ...primarySamples.map((sample) => sample.value),
      ...secondarySamples.map((sample) => sample.value),
    ];
    final primaryStats = _SeriesStats.from(primarySamples);
    final secondaryStats = _SeriesStats.from(secondarySamples);
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.show_chart_rounded, color: accent, size: 19),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE ANALYTICS',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Network Activity',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SeriesStatCard(label: primaryLabel, stats: primaryStats),
              if (secondarySamples.isNotEmpty)
                _SeriesStatCard(
                  label: secondaryLabel,
                  stats: secondaryStats,
                  color: Colors.purpleAccent,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: allValues.length < 2
                ? Center(
                    child: Text(
                      'Collecting live network samples…',
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 10,
                      ),
                    ),
                  )
                : LineChart(
                    _chartData(context, allValues),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  ),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(BuildContext context, List<double> values) {
    final maximum = math.max(1.0, values.reduce(math.max) * 1.18);
    final sampleCount = math.max(
      primarySamples.length,
      secondarySamples.length,
    );
    return LineChartData(
      minX: 0,
      maxX: math.max(1, sampleCount - 1).toDouble(),
      minY: 0,
      maxY: maximum,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: maximum / 4,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.overlay(context, 0.05), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 58,
            interval: maximum / 4,
            getTitlesWidget: (value, _) => Text(
              _formatNetworkRate(value),
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 8,
              ),
            ),
          ),
        ),
      ),
      lineBarsData: [
        if (primarySamples.isNotEmpty) _line(primarySamples, Colors.cyanAccent),
        if (secondarySamples.isNotEmpty)
          _line(secondarySamples, Colors.purpleAccent),
      ],
    );
  }

  LineChartBarData _line(List<TelemetrySample> samples, Color color) {
    return LineChartBarData(
      spots: [
        for (var index = 0; index < samples.length; index++)
          FlSpot(index.toDouble(), samples[index].value),
      ],
      isCurved: true,
      curveSmoothness: 0.32,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _AdapterAnalytics extends StatelessWidget {
  final NetworkInterfaceInfo interface;
  final NetworkSnapshot? snapshot;

  const _AdapterAnalytics({required this.interface, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final details = [
      ('Status', interface.connectionStatus),
      (
        'Type',
        interface.isLoopback
            ? 'Loopback'
            : interface.isVirtual
            ? 'Virtual'
            : 'Physical / system',
      ),
      ('IPv4', interface.ipv4 ?? 'Unavailable'),
      ('IPv6', interface.ipv6 ?? 'Unavailable'),
      ('MAC address', interface.macAddress ?? 'Unavailable'),
      (
        'Link speed',
        interface.speedMbps == 0
            ? 'Unavailable'
            : '${interface.speedMbps} Mbps',
      ),
      ('MTU', interface.mtu == 0 ? 'Unavailable' : '${interface.mtu}'),
      ('Gateway', snapshot?.gateway ?? 'Unavailable'),
      ('Received', _formatNetworkBytes(interface.bytesReceived)),
      ('Sent', _formatNetworkBytes(interface.bytesSent)),
      ('Packets received', '${interface.packetsReceived}'),
      ('Packets sent', '${interface.packetsSent}'),
    ];
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTERFACE DETAILS',
            style: TextStyle(
              color: Colors.tealAccent,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            interface.displayName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final detail in details)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.overlay(context, 0.03),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.$1,
                              style: TextStyle(
                                color: AppColors.textMuted(context),
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              detail.$2,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FocusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _FocusPill({required this.icon, required this.label, this.color});

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesStatCard extends StatelessWidget {
  final String label;
  final _SeriesStats stats;
  final Color color;

  const _SeriesStatCard({
    required this.label,
    required this.stats,
    this.color = Colors.cyanAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _formatNetworkRate(stats.current),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Average ${_formatNetworkRate(stats.average)} · Peak ${_formatNetworkRate(stats.peak)}',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _SeriesStats {
  final double current;
  final double average;
  final double peak;

  const _SeriesStats({
    required this.current,
    required this.average,
    required this.peak,
  });

  factory _SeriesStats.from(List<TelemetrySample> samples) {
    if (samples.isEmpty) {
      return const _SeriesStats(current: 0, average: 0, peak: 0);
    }
    final values = samples.map((sample) => sample.value).toList();
    return _SeriesStats(
      current: values.last,
      average: values.reduce((a, b) => a + b) / values.length,
      peak: values.reduce(math.max),
    );
  }
}

String _formatNetworkRate(double bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${bytesPerSecond.toStringAsFixed(0)} B/s';
}

String _formatNetworkBytes(num bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
