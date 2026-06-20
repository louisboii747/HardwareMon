import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/network_models.dart';
import '../../models/telemetry_sample.dart';
import '../../services/network_service.dart';
import '../../widgets/glass_panel.dart';
import '../network_focus_screen.dart';

enum _BandwidthMode { download, upload, both }

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final NetworkService _service = NetworkService();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _adapterSearchController =
      TextEditingController();

  Timer? _networkTimer;
  Timer? _livePingTimer;
  NetworkSnapshot? _snapshot;
  String? _selectedInterfaceName;
  String? _networkError;
  bool _networkLoading = true;
  bool _activeAdaptersOnly = false;
  _BandwidthMode _bandwidthMode = _BandwidthMode.both;
  final List<_BandwidthSample> _bandwidthHistory = [];
  int _bandwidthSamples = 0;
  double _downloadTotal = 0;
  double _uploadTotal = 0;
  double _peakDownload = 0;
  double _peakUpload = 0;
  int _sessionDownloadBaseline = 0;
  int _sessionUploadBaseline = 0;

  PingResult? _pingResult;
  String? _inputError;
  String? _pingTransportError;
  bool _pingLoading = false;
  bool _livePing = false;
  final List<_LatencySample> _latencyHistory = [];
  final List<double> _successfulLatencies = [];
  int _pingAttempts = 0;
  int _pingReplies = 0;
  List<String> _recentTargets = const [];
  List<String> _favouriteTargets = const [];

  @override
  void initState() {
    super.initState();
    _targetController.addListener(_onTargetChanged);
    _adapterSearchController.addListener(_onAdapterSearchChanged);
    unawaited(_loadSavedTargets());
    unawaited(_loadNetwork());
    _networkTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_loadNetwork(silent: true)),
    );
  }

  @override
  void dispose() {
    _networkTimer?.cancel();
    _livePingTimer?.cancel();
    _targetController
      ..removeListener(_onTargetChanged)
      ..dispose();
    _adapterSearchController
      ..removeListener(_onAdapterSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onTargetChanged() {
    if (!mounted) return;
    setState(() {
      if (_inputError != null) _inputError = null;
    });
  }

  void _onAdapterSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedTargets() async {
    final results = await Future.wait<Object?>([
      _service.loadRecentTargets(),
      _service.loadFavouriteTargets(),
      _service.loadSelectedInterface(),
    ]);
    if (!mounted) return;
    setState(() {
      _recentTargets = results[0] as List<String>;
      _favouriteTargets = results[1] as List<String>;
      _selectedInterfaceName ??= results[2] as String?;
    });
  }

  NetworkInterfaceInfo? get _selectedInterface {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final interface in snapshot.interfaces) {
      if (interface.name == _selectedInterfaceName) return interface;
    }
    return null;
  }

  Future<void> _loadNetwork({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _networkLoading = true);
    }

    try {
      final snapshot = await _service.fetchSnapshot();
      if (!mounted) return;

      final firstReading = _snapshot == null;
      final previousSelectedName = _selectedInterfaceName;
      final selectedName = chooseNetworkInterfaceName(
        snapshot,
        _selectedInterfaceName,
        firstReading: firstReading,
      );
      final selected = snapshot.interfaces
          .cast<NetworkInterfaceInfo?>()
          .firstWhere((item) => item?.name == selectedName, orElse: () => null);

      setState(() {
        _snapshot = snapshot;
        _selectedInterfaceName = selectedName;
        _networkError = null;
        _networkLoading = false;

        if (selected != null) {
          _bandwidthHistory.add(
            _BandwidthSample(
              timestamp: snapshot.sampledAt,
              downloadBps: selected.downloadBps,
              uploadBps: selected.uploadBps,
            ),
          );
          if (_bandwidthHistory.length > 90) {
            _bandwidthHistory.removeAt(0);
          }
          _bandwidthSamples++;
          _downloadTotal += selected.downloadBps;
          _uploadTotal += selected.uploadBps;
          _peakDownload = math.max(_peakDownload, selected.downloadBps);
          _peakUpload = math.max(_peakUpload, selected.uploadBps);
          if (firstReading) {
            _sessionDownloadBaseline = 0;
            _sessionUploadBaseline = 0;
          }
        }
      });
      if (selectedName != null && selectedName != previousSelectedName) {
        unawaited(_service.saveSelectedInterface(selectedName));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _networkLoading = false;
        _networkError = error.toString();
      });
    }
  }

  void _selectInterface(String name) {
    if (_selectedInterfaceName == name) return;
    setState(() {
      _selectedInterfaceName = name;
      _resetBandwidthSessionInternal();
    });
    unawaited(_service.saveSelectedInterface(name));
  }

  void _resetBandwidthSession() {
    setState(_resetBandwidthSessionInternal);
    _showToast('Network session counters reset');
  }

  void _resetBandwidthSessionInternal() {
    final selected = _selectedInterface;
    _bandwidthHistory.clear();
    _bandwidthSamples = 0;
    _downloadTotal = 0;
    _uploadTotal = 0;
    _peakDownload = 0;
    _peakUpload = 0;
    _sessionDownloadBaseline = selected?.sessionBytesReceived ?? 0;
    _sessionUploadBaseline = selected?.sessionBytesSent ?? 0;
  }

  List<NetworkInterfaceInfo> get _filteredInterfaces {
    final query = _adapterSearchController.text.trim().toLowerCase();
    final interfaces = _snapshot?.interfaces ?? const <NetworkInterfaceInfo>[];
    return interfaces
        .where((interface) {
          if (_activeAdaptersOnly && !interface.isUp) return false;
          if (query.isEmpty) return true;
          return interface.name.toLowerCase().contains(query) ||
              (interface.ipv4?.toLowerCase().contains(query) ?? false) ||
              (interface.ipv6?.toLowerCase().contains(query) ?? false) ||
              (interface.macAddress?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
  }

  Future<void> _runPing({int count = 4, bool showToast = true}) async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() => _inputError = 'Enter a host, URL, domain, or IP address.');
      return;
    }
    if (_pingLoading) return;

    setState(() {
      _pingLoading = true;
      _inputError = null;
      _pingTransportError = null;
    });

    try {
      final result = await _service.ping(target, count: count, timeout: 2);
      if (!mounted) return;

      final now = DateTime.now();
      final latencies = result.sampleLatenciesMs;
      setState(() {
        _pingResult = result;
        _pingAttempts += count;
        _pingReplies += result.samples;
        for (var index = 0; index < latencies.length; index++) {
          final latency = latencies[index];
          _successfulLatencies.add(latency);
          _latencyHistory.add(
            _LatencySample(
              timestamp: now.add(Duration(milliseconds: index)),
              latencyMs: latency,
            ),
          );
        }
        if (_latencyHistory.length > 90) {
          _latencyHistory.removeRange(0, _latencyHistory.length - 90);
        }
      });
      await _loadSavedTargets();
      if (!mounted || !showToast) return;
      _showToast(
        result.reachable
            ? '${result.target} replied in ${_formatMilliseconds(result.latencyMs)}'
            : result.error ?? 'Target did not reply',
        error: !result.reachable,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _pingTransportError = error.toString());
      if (showToast) {
        _showToast('The ping request could not be completed', error: true);
      }
    } finally {
      if (mounted) setState(() => _pingLoading = false);
    }
  }

  Future<void> _startLivePing() async {
    if (_livePing) return;
    if (_targetController.text.trim().isEmpty) {
      setState(() => _inputError = 'Enter a target before starting live ping.');
      return;
    }

    setState(() => _livePing = true);
    await _runPing(count: 1);
    if (!mounted || !_livePing) return;
    _livePingTimer?.cancel();
    _livePingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_pingLoading) unawaited(_runPing(count: 1, showToast: false));
    });
  }

  void _stopLivePing({bool notify = true}) {
    _livePingTimer?.cancel();
    _livePingTimer = null;
    if (mounted) setState(() => _livePing = false);
    if (notify) _showToast('Live ping stopped');
  }

  void _clearPingSession() {
    _stopLivePing(notify: false);
    setState(() {
      _pingResult = null;
      _pingTransportError = null;
      _inputError = null;
      _latencyHistory.clear();
      _successfulLatencies.clear();
      _pingAttempts = 0;
      _pingReplies = 0;
    });
  }

  Future<void> _clearRecentTargets() async {
    await _service.clearRecentTargets();
    if (!mounted) return;
    setState(() => _recentTargets = const []);
    _showToast('Recent ping history cleared');
  }

  Future<void> _toggleFavourite() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      setState(() => _inputError = 'Enter a target before adding a favourite.');
      return;
    }
    final favourites = await _service.toggleFavourite(target);
    if (!mounted) return;
    setState(() => _favouriteTargets = favourites);
    _showToast(
      favourites.contains(target)
          ? '$target added to favourites'
          : '$target removed from favourites',
    );
  }

  void _useTarget(String target, {bool runImmediately = false}) {
    _targetController.text = target;
    _targetController.selection = TextSelection.collapsed(
      offset: target.length,
    );
    if (runImmediately) unawaited(_runPing());
  }

  Future<void> _copyPingResult() async {
    final result = _pingResult;
    if (result == null) return;
    final summary =
        '''
HardwareMon Ping Result
Target: ${result.target}
Resolved host: ${result.resolvedHost ?? 'Unavailable'}
Status: $_pingStatusLabel
Current latency: ${_formatMilliseconds(result.latencyMs)}
Average latency: ${_formatMilliseconds(_sessionAverage)}
Minimum latency: ${_formatMilliseconds(_sessionMinimum)}
Maximum latency: ${_formatMilliseconds(_sessionMaximum)}
Jitter: ${_formatMilliseconds(_sessionJitter)}
Packet loss: ${_sessionPacketLoss.toStringAsFixed(1)}%
Samples: $_pingReplies
Last checked: ${result.checkedAt.toIso8601String()}
''';
    await Clipboard.setData(ClipboardData(text: summary.trim()));
    if (mounted) _showToast('Ping result copied');
  }

  void _showToast(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? Colors.redAccent : Colors.greenAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<TelemetrySample> get _downloadSamples => [
    for (final sample in _bandwidthHistory)
      TelemetrySample(timestamp: sample.timestamp, value: sample.downloadBps),
  ];

  List<TelemetrySample> get _uploadSamples => [
    for (final sample in _bandwidthHistory)
      TelemetrySample(timestamp: sample.timestamp, value: sample.uploadBps),
  ];

  void _openNetworkFocus({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    List<TelemetrySample> primarySamples = const [],
    List<TelemetrySample> secondarySamples = const [],
    String primaryLabel = 'Download',
    String secondaryLabel = 'Upload',
    NetworkInterfaceInfo? interfaceInfo,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: NetworkFocusScreen(
              title: title,
              value: value,
              subtitle: subtitle,
              icon: icon,
              accent: accent,
              primarySamples: primarySamples,
              secondarySamples: secondarySamples,
              primaryLabel: primaryLabel,
              secondaryLabel: secondaryLabel,
              interfaceInfo: interfaceInfo,
              snapshot: _snapshot,
            ),
          ),
        ),
      ),
    );
  }

  double? get _sessionAverage => _successfulLatencies.isEmpty
      ? null
      : _successfulLatencies.reduce((a, b) => a + b) /
            _successfulLatencies.length;

  double? get _sessionMinimum => _successfulLatencies.isEmpty
      ? null
      : _successfulLatencies.reduce(math.min);

  double? get _sessionMaximum => _successfulLatencies.isEmpty
      ? null
      : _successfulLatencies.reduce(math.max);

  double? get _sessionJitter {
    if (_successfulLatencies.length < 2) return 0;
    var total = 0.0;
    for (var index = 1; index < _successfulLatencies.length; index++) {
      total += (_successfulLatencies[index] - _successfulLatencies[index - 1])
          .abs();
    }
    return total / (_successfulLatencies.length - 1);
  }

  double get _sessionPacketLoss => _pingAttempts == 0
      ? 0
      : ((_pingAttempts - _pingReplies) / _pingAttempts) * 100;

  PingHealth get _pingHealth {
    final result = _pingResult;
    if (_pingTransportError != null) return PingHealth.error;
    if (result == null) return PingHealth.error;
    if (!result.reachable) return result.health;
    if ((_sessionAverage ?? 0) >= 150 || _sessionPacketLoss > 10) {
      return PingHealth.slow;
    }
    return PingHealth.online;
  }

  String get _pingStatusLabel {
    if (_pingTransportError != null) return 'Error';
    return switch (_pingHealth) {
      PingHealth.online => 'Online',
      PingHealth.slow => 'Slow',
      PingHealth.unreachable => 'Unreachable',
      PingHealth.error => 'Error',
    };
  }

  Color get _pingColor => switch (_pingHealth) {
    PingHealth.online => Colors.greenAccent,
    PingHealth.slow => Colors.amberAccent,
    PingHealth.unreachable => Colors.redAccent,
    PingHealth.error => Colors.deepOrangeAccent,
  };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadNetwork,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context),
            if (_networkError != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(
                message:
                    'Network telemetry is disconnected. The tester will retry through the local backend.',
                onRetry: _loadNetwork,
              ),
            ],
            const SizedBox(height: 20),
            _buildOverview(context),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final bandwidth = _buildBandwidthPanel(context);
                final flow = _buildFlowPanel(context);
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [bandwidth, const SizedBox(height: 20), flow],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: bandwidth),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: flow),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _buildInterfacesPanel(context),
            const SizedBox(height: 20),
            _buildPingCockpit(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final online = _snapshot?.connectionStatus == 'online';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Network',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Live adapter telemetry and a safe endpoint troubleshooting cockpit.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _StatusPill(
          label: _networkLoading
              ? 'Connecting'
              : online
              ? 'Network online'
              : 'Network offline',
          color: _networkLoading
              ? Colors.cyanAccent
              : online
              ? Colors.greenAccent
              : Colors.redAccent,
          busy: _networkLoading,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Refresh network telemetry',
          child: IconButton(
            onPressed: _networkLoading ? null : _loadNetwork,
            icon: _networkLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context) {
    final selected = _selectedInterface;
    final cards = [
      _NetworkMetricCard(
        label: 'Download',
        value: _formatRate(selected?.downloadBps ?? 0),
        detail: 'Receiving now',
        icon: Icons.south_rounded,
        color: Colors.cyanAccent,
        onOpen: () => _openNetworkFocus(
          title: 'Download',
          value: _formatRate(selected?.downloadBps ?? 0),
          subtitle: 'Realtime receive throughput',
          icon: Icons.south_rounded,
          accent: Colors.cyanAccent,
          primarySamples: _downloadSamples,
          interfaceInfo: selected,
        ),
      ),
      _NetworkMetricCard(
        label: 'Upload',
        value: _formatRate(selected?.uploadBps ?? 0),
        detail: 'Sending now',
        icon: Icons.north_rounded,
        color: Colors.purpleAccent,
        onOpen: () => _openNetworkFocus(
          title: 'Upload',
          value: _formatRate(selected?.uploadBps ?? 0),
          subtitle: 'Realtime send throughput',
          icon: Icons.north_rounded,
          accent: Colors.purpleAccent,
          primarySamples: _uploadSamples,
          primaryLabel: 'Upload',
          interfaceInfo: selected,
        ),
      ),
      _NetworkMetricCard(
        label: 'Downloaded',
        value: _formatBytes(
          math.max(
            0,
            (selected?.sessionBytesReceived ?? 0) - _sessionDownloadBaseline,
          ),
        ),
        detail: 'This session',
        icon: Icons.cloud_download_outlined,
        color: Colors.lightBlueAccent,
        onOpen: () => _openNetworkFocus(
          title: 'Downloaded',
          value: _formatBytes(
            math.max(
              0,
              (selected?.sessionBytesReceived ?? 0) - _sessionDownloadBaseline,
            ),
          ),
          subtitle: 'Data received during this Network page session',
          icon: Icons.cloud_download_outlined,
          accent: Colors.lightBlueAccent,
          primarySamples: _downloadSamples,
          interfaceInfo: selected,
        ),
      ),
      _NetworkMetricCard(
        label: 'Uploaded',
        value: _formatBytes(
          math.max(
            0,
            (selected?.sessionBytesSent ?? 0) - _sessionUploadBaseline,
          ),
        ),
        detail: 'This session',
        icon: Icons.cloud_upload_outlined,
        color: Colors.orangeAccent,
        onOpen: () => _openNetworkFocus(
          title: 'Uploaded',
          value: _formatBytes(
            math.max(
              0,
              (selected?.sessionBytesSent ?? 0) - _sessionUploadBaseline,
            ),
          ),
          subtitle: 'Data sent during this Network page session',
          icon: Icons.cloud_upload_outlined,
          accent: Colors.orangeAccent,
          primarySamples: _uploadSamples,
          primaryLabel: 'Upload',
          interfaceInfo: selected,
        ),
      ),
      _NetworkMetricCard(
        label: 'Active interface',
        value: selected?.displayName ?? 'No adapter',
        detail: selected?.isVirtual == true
            ? 'Virtual interface'
            : selected?.isUp == true
            ? 'Link active'
            : 'Link inactive',
        icon: Icons.settings_ethernet_rounded,
        color: Colors.greenAccent,
        onOpen: () => _openNetworkFocus(
          title: 'Active Interface',
          value: selected?.displayName ?? 'No adapter',
          subtitle: selected?.isVirtual == true
              ? 'Virtual network interface'
              : 'Current routed network interface',
          icon: Icons.settings_ethernet_rounded,
          accent: Colors.greenAccent,
          primarySamples: _downloadSamples,
          secondarySamples: _uploadSamples,
          interfaceInfo: selected,
        ),
      ),
      _NetworkMetricCard(
        label: 'Local IP',
        value: selected?.ipv4 ?? selected?.ipv6 ?? 'Unavailable',
        detail: _snapshot?.gateway == null
            ? 'Gateway unavailable'
            : 'Gateway ${_snapshot!.gateway}',
        icon: Icons.lan_outlined,
        color: Colors.tealAccent,
        copyValue: selected?.ipv4 ?? selected?.ipv6,
        onOpen: () => _openNetworkFocus(
          title: 'Local IP',
          value: selected?.ipv4 ?? selected?.ipv6 ?? 'Unavailable',
          subtitle: _snapshot?.gateway == null
              ? 'Gateway unavailable'
              : 'Gateway ${_snapshot!.gateway}',
          icon: Icons.lan_outlined,
          accent: Colors.tealAccent,
          primarySamples: _downloadSamples,
          secondarySamples: _uploadSamples,
          interfaceInfo: selected,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _buildBandwidthPanel(BuildContext context) {
    final selected = _selectedInterface;
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Live bandwidth',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<_BandwidthMode>(
                tooltip: 'Choose graph series',
                initialValue: _bandwidthMode,
                onSelected: (value) => setState(() => _bandwidthMode = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _BandwidthMode.download,
                    child: Text('Download only'),
                  ),
                  PopupMenuItem(
                    value: _BandwidthMode.upload,
                    child: Text('Upload only'),
                  ),
                  PopupMenuItem(
                    value: _BandwidthMode.both,
                    child: Text('Upload + Download'),
                  ),
                ],
                child: _CompactControl(
                  icon: Icons.tune_rounded,
                  label: switch (_bandwidthMode) {
                    _BandwidthMode.download => 'Download',
                    _BandwidthMode.upload => 'Upload',
                    _BandwidthMode.both => 'Both',
                  },
                ),
              ),
              IconButton(
                tooltip: 'Open fullscreen bandwidth analytics',
                onPressed: () => _openNetworkFocus(
                  title: 'Live Bandwidth',
                  value: _formatRate(
                    (selected?.downloadBps ?? 0) + (selected?.uploadBps ?? 0),
                  ),
                  subtitle:
                      '${selected?.displayName ?? 'No adapter'} · combined throughput',
                  icon: Icons.show_chart_rounded,
                  accent: Colors.cyanAccent,
                  primarySamples: _downloadSamples,
                  secondarySamples: _uploadSamples,
                  interfaceInfo: selected,
                ),
                icon: const Icon(Icons.open_in_full_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendDot(color: Colors.cyanAccent, label: 'Download'),
              const SizedBox(width: 14),
              _LegendDot(color: Colors.purpleAccent, label: 'Upload'),
              const Spacer(),
              Text(
                '${_bandwidthHistory.length} samples',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: _bandwidthHistory.length < 2
                ? _ChartEmptyState(
                    icon: Icons.waves_rounded,
                    message: _networkLoading
                        ? 'Listening for network traffic…'
                        : 'Bandwidth history will appear as traffic flows.',
                  )
                : LineChart(
                    _bandwidthChartData(context),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InlineStat(
                label: 'Peak down',
                value: _formatRate(_peakDownload),
              ),
              _InlineStat(label: 'Peak up', value: _formatRate(_peakUpload)),
              _InlineStat(
                label: 'Average down',
                value: _formatRate(
                  _bandwidthSamples == 0
                      ? 0
                      : _downloadTotal / _bandwidthSamples,
                ),
              ),
              _InlineStat(
                label: 'Average up',
                value: _formatRate(
                  _bandwidthSamples == 0 ? 0 : _uploadTotal / _bandwidthSamples,
                ),
              ),
              TextButton.icon(
                onPressed: _resetBandwidthSession,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _bandwidthChartData(BuildContext context) {
    final maxValue = _bandwidthHistory.fold<double>(
      1,
      (maximum, sample) =>
          math.max(maximum, math.max(sample.downloadBps, sample.uploadBps)),
    );
    final showDownload = _bandwidthMode != _BandwidthMode.upload;
    final showUpload = _bandwidthMode != _BandwidthMode.download;

    return LineChartData(
      minX: 0,
      maxX: (_bandwidthHistory.length - 1).toDouble(),
      minY: 0,
      maxY: maxValue * 1.2,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.overlay(context, 0.05), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  _formatRate(spot.y),
                  TextStyle(
                    color: spot.barIndex == 0
                        ? Colors.cyanAccent
                        : Colors.purpleAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
      lineBarsData: [
        if (showDownload)
          _bandwidthLine(
            Colors.cyanAccent,
            _bandwidthHistory
                .asMap()
                .entries
                .map(
                  (entry) =>
                      FlSpot(entry.key.toDouble(), entry.value.downloadBps),
                )
                .toList(growable: false),
          ),
        if (showUpload)
          _bandwidthLine(
            Colors.purpleAccent,
            _bandwidthHistory
                .asMap()
                .entries
                .map(
                  (entry) =>
                      FlSpot(entry.key.toDouble(), entry.value.uploadBps),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  LineChartBarData _bandwidthLine(Color color, List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.32,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.4,
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

  Widget _buildFlowPanel(BuildContext context) {
    final selected = _selectedInterface;
    final totalRate = (selected?.downloadBps ?? 0) + (selected?.uploadBps ?? 0);
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: Colors.greenAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Connection flow',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open interface analytics',
                onPressed: selected == null
                    ? null
                    : () => _openNetworkFocus(
                        title: 'Connection Flow',
                        value: selected.displayName,
                        subtitle: _snapshot?.gateway == null
                            ? 'Gateway unavailable'
                            : 'Route through ${_snapshot!.gateway}',
                        icon: Icons.hub_outlined,
                        accent: Colors.greenAccent,
                        primarySamples: _downloadSamples,
                        secondarySamples: _uploadSamples,
                        interfaceInfo: selected,
                      ),
                icon: const Icon(Icons.open_in_full_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalRate > 1024 * 1024
                ? 'Burst traffic detected'
                : totalRate > 1024
                ? 'Traffic is flowing'
                : 'Link is idle',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 11),
          ),
          const SizedBox(height: 22),
          _NetworkFlow(
            adapter: selected?.displayName ?? 'No adapter',
            gateway: _snapshot?.gateway,
            active: selected?.isUp == true,
            intensity: (totalRate / (5 * 1024 * 1024))
                .clamp(0.05, 1)
                .toDouble(),
          ),
          const SizedBox(height: 24),
          _FlowDetail(
            label: 'Packets sent',
            value: '${selected?.packetsSent ?? 0}',
          ),
          const SizedBox(height: 10),
          _FlowDetail(
            label: 'Packets received',
            value: '${selected?.packetsReceived ?? 0}',
          ),
          const SizedBox(height: 10),
          _FlowDetail(
            label: 'Link speed',
            value: selected == null || selected.speedMbps == 0
                ? 'Unknown'
                : '${selected.speedMbps} Mbps',
          ),
          const SizedBox(height: 10),
          _FlowDetail(
            label: 'MTU',
            value: selected == null || selected.mtu == 0
                ? 'Unknown'
                : '${selected.mtu}',
          ),
        ],
      ),
    );
  }

  Widget _buildInterfacesPanel(BuildContext context) {
    final interfaces = _filteredInterfaces;
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.router_outlined, color: Colors.tealAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Network interfaces',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilterChip(
                selected: _activeAdaptersOnly,
                onSelected: (value) =>
                    setState(() => _activeAdaptersOnly = value),
                label: const Text('Active only'),
                avatar: const Icon(Icons.bolt_rounded, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _adapterSearchController,
            decoration: const InputDecoration(
              hintText: 'Filter by adapter, IP, or MAC address',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          if (interfaces.isEmpty)
            _ChartEmptyState(
              icon: Icons.portable_wifi_off_rounded,
              message: _snapshot?.interfaces.isEmpty == true
                  ? 'No network interfaces are currently available.'
                  : 'No adapters match this filter.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final interface in interfaces)
                  _AdapterChip(
                    interface: interface,
                    selected: interface.name == _selectedInterfaceName,
                    onSelected: () => _selectInterface(interface.name),
                    onDetails: () => _showAdapterDetails(interface),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showAdapterDetails(NetworkInterfaceInfo interface) {
    _openNetworkFocus(
      title: interface.displayName,
      value: interface.isUp ? 'Online' : 'Offline',
      subtitle: interface.isVirtual
          ? 'Virtual network interface'
          : 'Network interface analytics',
      icon: interface.isUp
          ? Icons.lan_rounded
          : Icons.portable_wifi_off_rounded,
      accent: interface.isUp ? Colors.greenAccent : Colors.redAccent,
      primarySamples: interface.name == _selectedInterfaceName
          ? _downloadSamples
          : const [],
      secondarySamples: interface.name == _selectedInterfaceName
          ? _uploadSamples
          : const [],
      interfaceInfo: interface,
    );
    return Future.value();
  }

  Widget _buildPingCockpit(BuildContext context) {
    final currentTarget = _targetController.text.trim();
    final isFavourite = _favouriteTargets.contains(currentTarget);
    return GlassPanel(
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
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ping / Endpoint Tester',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Resolve and test a URL, domain, host, or IP without running raw shell input.',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              if (_pingResult != null || _pingTransportError != null)
                _StatusPill(
                  label: _pingStatusLabel,
                  color: _pingColor,
                  busy: _pingLoading,
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => unawaited(_runPing()),
            decoration: InputDecoration(
              labelText: 'Target',
              hintText: 'google.com, https://github.com, or 192.168.1.1',
              errorText: _inputError,
              prefixIcon: const Icon(Icons.language_rounded),
              suffixIcon: IconButton(
                tooltip: isFavourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                onPressed: _toggleFavourite,
                icon: Icon(
                  isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavourite ? Colors.amberAccent : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Quick targets',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
              _TargetChip(
                label: 'Cloudflare DNS',
                target: '1.1.1.1',
                icon: Icons.cloud_outlined,
                onPressed: () => _useTarget('1.1.1.1', runImmediately: true),
              ),
              _TargetChip(
                label: 'Google DNS',
                target: '8.8.8.8',
                icon: Icons.public_rounded,
                onPressed: () => _useTarget('8.8.8.8', runImmediately: true),
              ),
              _TargetChip(
                label: 'GitHub',
                target: 'github.com',
                icon: Icons.code_rounded,
                onPressed: () => _useTarget('github.com', runImmediately: true),
              ),
              if (_snapshot?.gateway != null)
                _TargetChip(
                  label: 'Use router / gateway',
                  target: _snapshot!.gateway!,
                  icon: Icons.router_rounded,
                  onPressed: () =>
                      _useTarget(_snapshot!.gateway!, runImmediately: true),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _pingLoading ? null : _runPing,
                icon: _pingLoading && !_livePing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_ping_rounded),
                label: const Text('Ping'),
              ),
              FilledButton.tonalIcon(
                onPressed: _livePing ? null : _startLivePing,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Live Ping'),
              ),
              OutlinedButton.icon(
                onPressed: _livePing ? _stopLivePing : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              ),
              TextButton.icon(
                onPressed: _pingResult == null && _latencyHistory.isEmpty
                    ? null
                    : _clearPingSession,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear'),
              ),
              TextButton.icon(
                onPressed: _pingResult == null ? null : _copyPingResult,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy result'),
              ),
            ],
          ),
          if (_livePing) ...[
            const SizedBox(height: 12),
            const _LivePingBanner(),
          ],
          if (_pingTransportError != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(
              message:
                  'The local backend could not complete the request. Check that HardwareMon telemetry is connected.',
              onRetry: _runPing,
            ),
          ],
          const SizedBox(height: 20),
          if (_pingResult == null && _pingTransportError == null)
            const _PingEmptyState()
          else if (_pingResult != null)
            _buildPingResults(context),
          if (_favouriteTargets.isNotEmpty || _recentTargets.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildTargetHistory(context),
          ],
        ],
      ),
    );
  }

  Widget _buildPingResults(BuildContext context) {
    final result = _pingResult!;
    final metrics = [
      _PingMetric(
        label: 'Current',
        value: _formatMilliseconds(result.latencyMs),
      ),
      _PingMetric(
        label: 'Average',
        value: _formatMilliseconds(_sessionAverage),
      ),
      _PingMetric(
        label: 'Minimum',
        value: _formatMilliseconds(_sessionMinimum),
      ),
      _PingMetric(
        label: 'Maximum',
        value: _formatMilliseconds(_sessionMaximum),
      ),
      _PingMetric(
        label: 'Packet loss',
        value: '${_sessionPacketLoss.toStringAsFixed(1)}%',
      ),
      _PingMetric(label: 'Jitter', value: _formatMilliseconds(_sessionJitter)),
      _PingMetric(label: 'Samples', value: '$_pingReplies'),
      _PingMetric(
        label: 'Last checked',
        value: DateFormat('HH:mm:ss').format(result.checkedAt),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final gauge = _LatencyGauge(
              latency: result.latencyMs,
              status: _pingStatusLabel,
              color: _pingColor,
            );
            final grid = _PingMetricGrid(metrics: metrics);
            if (constraints.maxWidth < 760) {
              return Column(
                children: [gauge, const SizedBox(height: 18), grid],
              );
            }
            return Row(
              children: [
                SizedBox(width: 230, child: gauge),
                const SizedBox(width: 26),
                Expanded(child: grid),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _pingColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _pingColor.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Icon(Icons.dns_rounded, color: _pingColor, size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  result.error ??
                      '${result.target} resolved to ${result.resolvedHost ?? 'an unknown address'}',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Live latency',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              _livePing ? 'Sampling every 3 seconds' : 'Session history',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: _latencyHistory.length < 2
              ? const _ChartEmptyState(
                  icon: Icons.timeline_rounded,
                  message:
                      'Run another sample or start Live Ping to draw the latency timeline.',
                )
              : LineChart(
                  _latencyChartData(context),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                ),
        ),
      ],
    );
  }

  LineChartData _latencyChartData(BuildContext context) {
    final maximum = _latencyHistory.fold<double>(
      20,
      (value, sample) => math.max(value, sample.latencyMs),
    );
    return LineChartData(
      minX: 0,
      maxX: (_latencyHistory.length - 1).toDouble(),
      minY: 0,
      maxY: maximum * 1.25,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.overlay(context, 0.05), strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} ms',
                  TextStyle(color: _pingColor, fontWeight: FontWeight.w700),
                ),
              )
              .toList(growable: false),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: _latencyHistory
              .asMap()
              .entries
              .map(
                (entry) => FlSpot(entry.key.toDouble(), entry.value.latencyMs),
              )
              .toList(growable: false),
          isCurved: true,
          curveSmoothness: 0.32,
          preventCurveOverShooting: true,
          color: _pingColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) =>
                FlDotCirclePainter(radius: 2.5, color: _pingColor),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _pingColor.withValues(alpha: 0.22),
                _pingColor.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_favouriteTargets.isNotEmpty) ...[
          const Text(
            'Favourite targets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in _favouriteTargets)
                ActionChip(
                  avatar: const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Colors.amberAccent,
                  ),
                  label: Text(target),
                  onPressed: () => _useTarget(target, runImmediately: true),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (_recentTargets.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'Recent targets',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearRecentTargets,
                icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                label: const Text('Clear history'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in _recentTargets)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: Text(target),
                  onPressed: () => _useTarget(target),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BandwidthSample {
  final DateTime timestamp;
  final double downloadBps;
  final double uploadBps;

  const _BandwidthSample({
    required this.timestamp,
    required this.downloadBps,
    required this.uploadBps,
  });
}

class _LatencySample {
  final DateTime timestamp;
  final double latencyMs;

  const _LatencySample({required this.timestamp, required this.latencyMs});
}

class _NetworkMetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final String? copyValue;
  final VoidCallback onOpen;

  const _NetworkMetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onOpen,
    this.copyValue,
  });

  @override
  State<_NetworkMetricCard> createState() => _NetworkMetricCardState();
}

class _NetworkMetricCardState extends State<_NetworkMetricCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedScale(
          scale: _hovering ? 1.012 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            height: 112,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(context).withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hovering
                    ? widget.color.withValues(alpha: 0.35)
                    : AppColors.border(context),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.09),
                        blurRadius: 24,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 19),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: AppColors.textMuted(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Text(
                          widget.value,
                          key: ValueKey(widget.value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open ${widget.label} fullscreen',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.open_in_full_rounded, size: 15),
                ),
                if (widget.copyValue != null)
                  IconButton(
                    tooltip: 'Copy ${widget.label}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.copyValue!),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.label} copied'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkFlow extends StatefulWidget {
  final String adapter;
  final String? gateway;
  final bool active;
  final double intensity;

  const _NetworkFlow({
    required this.adapter,
    required this.gateway,
    required this.active,
    required this.intensity,
  });

  @override
  State<_NetworkFlow> createState() => _NetworkFlowState();
}

class _NetworkFlowState extends State<_NetworkFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Colors.cyanAccent : Colors.redAccent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse =
            (0.25 +
                    (math.sin(_controller.value * math.pi * 2) + 1) *
                        0.25 *
                        widget.intensity)
                .clamp(0.2, 0.9)
                .toDouble();
        return Row(
          children: [
            const _FlowNode(icon: Icons.computer_rounded, label: 'This device'),
            Expanded(
              child: Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: pulse),
              ),
            ),
            _FlowNode(
              icon: Icons.settings_ethernet_rounded,
              label: widget.adapter,
              active: widget.active,
            ),
            Expanded(
              child: Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 1 - (pulse / 2)),
              ),
            ),
            _FlowNode(
              icon: widget.gateway == null
                  ? Icons.cloud_outlined
                  : Icons.router_rounded,
              label: widget.gateway ?? 'Internet',
              active: widget.active,
            ),
          ],
        );
      },
    );
  }
}

class _FlowNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _FlowNode({
    required this.icon,
    required this.label,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.cyanAccent : AppColors.textMuted(context);
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.09),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 9,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowDetail extends StatelessWidget {
  final String label;
  final String value;

  const _FlowDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _AdapterChip extends StatelessWidget {
  final NetworkInterfaceInfo interface;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onDetails;

  const _AdapterChip({
    required this.interface,
    required this.selected,
    required this.onSelected,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final color = interface.isUp ? Colors.greenAccent : Colors.redAccent;
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.14)
          : AppColors.overlay(context, 0.035),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minWidth: 210),
          padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interface.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      interface.ipv4 ??
                          (interface.isVirtual ? 'Virtual adapter' : 'No IPv4'),
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Adapter details',
                visualDensity: VisualDensity.compact,
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline_rounded, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatencyGauge extends StatelessWidget {
  final double? latency;
  final String status;
  final Color color;

  const _LatencyGauge({
    required this.latency,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = (latency ?? 0).clamp(0, 300).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _GaugePainter(
              value: animatedValue / 300,
              color: color,
              trackColor: AppColors.overlay(context, 0.07),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    latency == null ? '—' : latency!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
                    ),
                  ),
                  Text(
                    'milliseconds',
                    style: TextStyle(
                      color: AppColors.textMuted(context),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 18);
    final radius = math.min(size.width, size.height) * 0.38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [color.withValues(alpha: 0.5), color],
        transform: const GradientRotation(startAngle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, track);
    canvas.drawArc(rect, startAngle, sweep * value, false, active);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _PingMetric {
  final String label;
  final String value;

  const _PingMetric({required this.label, required this.value});
}

class _PingMetricGrid extends StatelessWidget {
  final List<_PingMetric> metrics;

  const _PingMetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overlay(context, 0.035),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: TextStyle(
                        color: AppColors.textMuted(context),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PingEmptyState extends StatelessWidget {
  const _PingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.travel_explore_rounded,
            size: 38,
            color: AppColors.accent.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 12),
          const Text(
            'Test a public endpoint, DNS server, local device, or router',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try google.com, https://github.com, 1.1.1.1, or a device on your LAN. '
            'Targets stay on this computer and are never synced.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePingBanner extends StatelessWidget {
  const _LivePingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 9),
          Text(
            'Live Ping is active · one bounded sample every 3 seconds',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final String target;
  final IconData icon;
  final VoidCallback onPressed;

  const _TargetChip({
    required this.label,
    required this.target,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: target,
      child: ActionChip(
        avatar: Icon(icon, size: 15),
        label: Text(label),
        onPressed: onPressed,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
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
            SizedBox(
              width: 9,
              height: 9,
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
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
            ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactControl extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactControl({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

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

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label  ',
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 9),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ChartEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted(context), size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final FutureOr<void> Function() onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
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
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 10, height: 1.35),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _formatRate(double bytesPerSecond) {
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

String _formatBytes(num bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${bytes.toStringAsFixed(0)} B';
}

String _formatMilliseconds(double? value) {
  return value == null ? '—' : '${value.toStringAsFixed(1)} ms';
}
