import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../core/theme/app_colors.dart';
import '../models/customization_preferences.dart';
import '../models/network_models.dart';
import '../services/network_service.dart';
import '../services/telemetry_service.dart';
import '../services/weather_service.dart';

class DashboardCompanionWidgets extends StatelessWidget {
  final TelemetryService telemetry;
  final CustomizationPreferences preferences;

  const DashboardCompanionWidgets({
    super.key,
    required this.telemetry,
    required this.preferences,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = preferences.widgetOrder
        .where(preferences.enabledWidgets.contains)
        .toList(growable: false);
    if (enabled.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'At a glance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '${enabled.length} active',
                  style: TextStyle(
                    color: AppColors.textMuted(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final id in enabled)
                  SizedBox(
                    key: ValueKey('dashboard-companion-${id.name}'),
                    width: cardWidth,
                    child: _widgetFor(id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _widgetFor(CustomWidgetId id) => switch (id) {
    CustomWidgetId.weather => _WeatherCard(
      location: preferences.weatherLocation,
    ),
    CustomWidgetId.networkSummary => const _NetworkSummaryCard(),
    CustomWidgetId.hardwareHealth => _HardwareHealthCard(telemetry: telemetry),
    CustomWidgetId.activityFeed => _ActivityCard(telemetry: telemetry),
    CustomWidgetId.benchmarks => const _SummaryCard(
      icon: Icons.speed_rounded,
      accent: Colors.purpleAccent,
      title: 'Benchmarks',
      value: 'Ready',
      detail: 'CPU, memory and disk tests are available from Benchmark.',
    ),
    CustomWidgetId.updates => const _UpdateCard(),
  };
}

class _WeatherCard extends StatefulWidget {
  final String location;

  const _WeatherCard({required this.location});

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  late final WeatherService _service;
  WeatherSnapshot? _snapshot;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = WeatherService();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) unawaited(_load());
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.location.trim().isEmpty) {
      setState(() {
        _snapshot = null;
        _error = 'Set a city or postcode in Settings.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.fetchCurrent(widget.location);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst(RegExp(r'^\w+: '), '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return _SummaryCard(
      icon: _weatherIcon(snapshot?.weatherCode),
      accent: Colors.lightBlueAccent,
      title: snapshot?.location ?? 'Weather',
      value: _loading
          ? 'Refreshing…'
          : snapshot == null
          ? 'Location needed'
          : '${snapshot.temperature.round()}°C',
      detail: snapshot == null
          ? (_error ?? 'Current weather unavailable.')
          : '${snapshot.condition} · Feels ${snapshot.apparentTemperature.round()}° · Wind ${snapshot.windSpeed.round()} km/h · Open-Meteo',
      onRefresh: widget.location.trim().isEmpty ? null : _load,
    );
  }
}

class _NetworkSummaryCard extends StatefulWidget {
  const _NetworkSummaryCard();

  @override
  State<_NetworkSummaryCard> createState() => _NetworkSummaryCardState();
}

class _NetworkSummaryCardState extends State<_NetworkSummaryCard> {
  final NetworkService _service = NetworkService();
  Timer? _timer;
  NetworkSnapshot? _snapshot;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Network telemetry unavailable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return _SummaryCard(
      icon: snapshot?.connectionStatus == 'online'
          ? Icons.wifi_rounded
          : Icons.wifi_off_rounded,
      accent: Colors.cyanAccent,
      title: 'Network Summary',
      value: snapshot?.activeInterface ?? 'Connecting…',
      detail: snapshot == null
          ? (_error ?? 'Reading the active adapter.')
          : '↓ ${_formatRate(snapshot.downloadBps)}  ↑ ${_formatRate(snapshot.uploadBps)} · ${snapshot.localIp ?? 'No local IP'}',
      onRefresh: _load,
    );
  }
}

class _HardwareHealthCard extends StatelessWidget {
  final TelemetryService telemetry;

  const _HardwareHealthCard({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final pressure = [
      telemetry.cpuUsage,
      telemetry.ramUsage,
      telemetry.diskUsage,
      if (telemetry.capabilities.supportsCpuTemperature)
        telemetry.cpuTemp.clamp(0, 100),
      if (telemetry.capabilities.supportsGpuTemperature)
        telemetry.gpuTemp.clamp(0, 100),
    ].fold<int>(0, (highest, value) => value > highest ? value : highest);
    final (label, detail, color) = pressure >= 90
        ? (
            'Needs attention',
            'One or more live metrics are in a critical range.',
            Colors.redAccent,
          )
        : pressure >= 75
        ? (
            'Elevated load',
            'The system is busy, but telemetry remains stable.',
            Colors.orangeAccent,
          )
        : (
            'Healthy',
            'Live CPU, memory, storage and thermal signals look normal.',
            Colors.greenAccent,
          );
    return _SummaryCard(
      icon: Icons.health_and_safety_rounded,
      accent: color,
      title: 'Hardware Health',
      value: label,
      detail: detail,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TelemetryService telemetry;

  const _ActivityCard({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final updated = telemetry.lastUpdated;
    return _SummaryCard(
      icon: Icons.dynamic_feed_rounded,
      accent: Colors.amberAccent,
      title: 'Activity Feed',
      value: telemetry.isPaused
          ? 'Monitoring paused'
          : telemetry.lastError != null
          ? 'Connection interrupted'
          : 'Telemetry active',
      detail: updated == null
          ? 'Waiting for the first local telemetry sample.'
          : 'Last sample ${_relativeTime(updated)} · CPU ${telemetry.cpuUsage}% · RAM ${telemetry.ramUsage}%',
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UpdateService.instance,
      builder: (context, _) {
        final state = UpdateService.instance.state;
        return _SummaryCard(
          icon: state.updateAvailable
              ? Icons.system_update_alt_rounded
              : Icons.verified_rounded,
          accent: state.updateAvailable
              ? Colors.orangeAccent
              : Colors.tealAccent,
          title: 'Updates',
          value: state.updateAvailable
              ? '${state.latestVersion} available'
              : 'Version ${state.currentVersion}',
          detail: state.statusMessage,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String value;
  final String detail;
  final Future<void> Function()? onRefresh;

  const _SummaryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.detail,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 9,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _weatherIcon(int? code) => switch (code) {
  0 => Icons.wb_sunny_rounded,
  1 || 2 => Icons.wb_cloudy_rounded,
  3 || 45 || 48 => Icons.cloud_rounded,
  51 ||
  53 ||
  55 ||
  56 ||
  57 ||
  61 ||
  63 ||
  65 ||
  66 ||
  67 ||
  80 ||
  81 ||
  82 => Icons.water_drop_rounded,
  71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
  95 || 96 || 99 => Icons.thunderstorm_rounded,
  _ => Icons.cloud_queue_rounded,
};

String _formatRate(double bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }
  return '${bytesPerSecond.toStringAsFixed(0)} B/s';
}

String _relativeTime(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inSeconds < 5) return 'just now';
  if (elapsed.inMinutes < 1) return '${elapsed.inSeconds}s ago';
  return '${elapsed.inMinutes}m ago';
}
