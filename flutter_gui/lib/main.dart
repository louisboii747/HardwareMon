// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// ─── Global hardware info ────────────────────────────────────────────────────
String cpuName = "—";
String gpuName = "—";
int ramTotal = 0;

// ─── Version Output ────────────────────────────────────────────────────

const String _kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev build',
);

// ─── Entry point ─────────────────────────────────────────────────────────────
// ─── Backend ───────────────────────────────────────────────────────────────

// ─── Backend ───────────────────────────────────────────────────────────────

Process? backendProcess;

String getBackendExecutable() {
  // Directory where the Flutter executable lives
  final exeDir = File(Platform.resolvedExecutable).parent.path;

  // Packaged backend binary
  final packagedBackend = '$exeDir/backend/api';

  if (File(packagedBackend).existsSync()) {
    return packagedBackend;
  }

  // Packaged python script fallback
  final packagedPython = '$exeDir/backend/api.py';

  if (File(packagedPython).existsSync()) {
    return packagedPython;
  }

  // Dev environment fallback
  return '${Platform.script.toFilePath().split('/flutter_gui/').first}/hardwaremon/api.py';
}

const backendApiUrl = 'http://127.0.0.1:5000/stats';
const backendHistoryUrl = 'http://127.0.0.1:5000/history';

Future<void> startBackend() async {
  try {
    final backendExecutable = getBackendExecutable();

    debugPrint('Launching backend: $backendExecutable');

    // Compiled backend binary
    if (!backendExecutable.endsWith('.py')) {
      backendProcess = await Process.start(
        backendExecutable,
        [],
        mode: ProcessStartMode.normal,
      );
    }
    // Python backend script
    else {
      final venvPython =
          '${Platform.script.toFilePath().split('/flutter_gui/').first}/.venv/bin/python3';

      backendProcess = await Process.start(
        File(venvPython).existsSync() ? venvPython : 'python3',
        [backendExecutable],
        mode: ProcessStartMode.normal,
      );
    }

    backendProcess!.stdout.transform(utf8.decoder).listen(debugPrint);

    backendProcess!.stderr.transform(utf8.decoder).listen(debugPrint);

    backendProcess!.exitCode.then((code) {
      debugPrint('Backend exited with code: $code');
    });

    debugPrint('HardwareMon backend started');
  } catch (e) {
    debugPrint('Backend start failed: $e');
  }
}

Future<void> stopBackend() async {
  try {
    if (backendProcess == null) return;

    backendProcess!.kill(ProcessSignal.sigterm);

    final exited = await backendProcess!.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );

    if (exited == -1) {
      backendProcess!.kill(ProcessSignal.sigkill);
    }

    debugPrint('Backend stopped');
  } catch (e) {
    debugPrint('Failed to stop backend: $e');
  }
}

Future<bool> waitForBackend() async {
  for (int i = 0; i < 20; i++) {
    try {
      final response = await http.get(Uri.parse(backendApiUrl));

      if (response.statusCode == 200) {
        debugPrint('Backend connected');
        return true;
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));
  }

  return false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await startBackend();
  await waitForBackend();

  runApp(const HardwareMonApp());
}

// ─── App root ─────────────────────────────────────────────────────────────────
class HardwareMonApp extends StatefulWidget {
  const HardwareMonApp({super.key});

  @override
  State<HardwareMonApp> createState() => _HardwareMonAppState();
}

class _HardwareMonAppState extends State<HardwareMonApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopBackend();
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await stopBackend();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HardwareMon',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: const HomePage(),
    );
  }
}

// ─── Design tokens ────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surface2 = Color(0xFF1C2128);
  static const sidebar = Color(0xFF0F1318);
  static const border = Color(0xFF30363D);
  static const cyan = Colors.cyanAccent;
  static const green = Colors.greenAccent;
  static const orange = Colors.orangeAccent;
  static const blue = Colors.blueAccent;
  static const purple = Colors.purpleAccent;
  static const red = Colors.redAccent;
}

// ─── Shell / Navigation ───────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedPage = 0;
  int _previousPage = 0;

  static const _labels = ['Dashboard', 'Processes', 'Settings'];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.list_alt_rounded,
    Icons.settings_rounded,
  ];

  void _navigateTo(int index) {
    if (index == _selectedPage) return;
    setState(() {
      _previousPage = _selectedPage;
      _selectedPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const ProcessesPage(),
      const SettingsPage(),
    ];

    final slideDir = _selectedPage > _previousPage ? 1.0 : -1.0;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 88,
            color: AppColors.sidebar,
            child: Column(
              children: [
                const SizedBox(height: 28),

                // Logo
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.memory_rounded,
                      size: 26,
                      color: AppColors.cyan,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                for (int i = 0; i < _labels.length; i++) ...[
                  _NavItem(
                    icon: _icons[i],
                    label: _labels[i],
                    active: _selectedPage == i,
                    onTap: () => _navigateTo(i),
                  ),
                  if (i < _labels.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // Divider
          Container(width: 1, color: AppColors.border),

          // ── Page area ────────────────────────────────────────────────────
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) {
                  final offset =
                      Tween<Offset>(
                        begin: Offset(0, slideDir * 0.04),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_selectedPage),
                  child: pages[_selectedPage],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final show = widget.active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: show ? AppColors.cyan.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: widget.active
                      ? AppColors.cyan
                      : _hovered
                      ? Colors.white
                      : Colors.white38,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: widget.active
                      ? AppColors.cyan
                      : _hovered
                      ? Colors.white70
                      : Colors.white24,
                ),
                child: Text(widget.label, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Current values
  int _cpuUsage = 0;
  int _ramUsage = 0;
  int _diskUsage = 0;
  double _uploadSpeed = 0;
  double _downloadSpeed = 0;
  int _gpuTemp = 0;
  String _currentTime = "";

  // Previous values (for animated tween)
  int _prevCpu = 0;
  int _prevRam = 0;
  int _prevDisk = 0;
  int _prevGpuTemp = 0;

  // Histories (max 30 pts each)
  final List<double> _cpuHistory = [];
  final List<double> _ramHistory = [];
  final List<double> _diskHistory = [];
  final List<double> _netDownHistory = [];
  final List<double> _netUpHistory = [];
  final List<double> _gpuTempHistory = [];

  // Per-core
  List<int> _coreUsages = [];
  final List<List<double>> _coreHistories = [];

  // State flags
  bool _connected = false;
  bool _firstLoad = true;
  int _failCount = 0;

  late Timer _timer;

  // ── Colour helpers ──────────────────────────────────────────────────────
  Color _tempColor(int t) {
    if (t >= 85) return AppColors.red;
    if (t >= 70) return AppColors.orange;
    return AppColors.green;
  }

  Color _usageColor(int u) {
    if (u >= 85) return AppColors.red;
    if (u >= 65) return AppColors.orange;
    return AppColors.cyan;
  }

  // ── Data fetch ──────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final response = await http.get(Uri.parse(backendHistoryUrl));

      if (response.statusCode != 200) {
        return;
      }

      final List<dynamic> data = jsonDecode(response.body);

      final reversed = data.reversed.toList();

      setState(() {
        _cpuHistory.clear();
        _ramHistory.clear();
        _gpuTempHistory.clear();

        for (final item in reversed) {
          _cpuHistory.add((item['cpu_percent'] as num?)?.toDouble() ?? 0);

          _ramHistory.add((item['ram_percent'] as num?)?.toDouble() ?? 0);

          _gpuTempHistory.add((item['cpu_temp'] as num?)?.toDouble() ?? 0);
        }
      });
    } catch (e) {
      debugPrint("loadHistory error: $e");
    }
  }

  Future<void> _fetchStats() async {
    try {
      final response = await http
          .get(Uri.parse(backendApiUrl))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        _handleFailure();
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _connected = true;
        _failCount = 0;
        _firstLoad = false;

        _prevCpu = _cpuUsage;
        _prevRam = _ramUsage;
        _prevDisk = _diskUsage;
        _prevGpuTemp = _gpuTemp;

        _cpuUsage = (data['cpu'] as num?)?.toInt() ?? _cpuUsage;
        _ramUsage = (data['ram'] as num?)?.toInt() ?? _ramUsage;
        _diskUsage = (data['disk'] as num?)?.toInt() ?? _diskUsage;
        _uploadSpeed = ((data['upload'] as num?)?.toDouble() ?? 0).clamp(
          0,
          100000,
        );

        _downloadSpeed = ((data['download'] as num?)?.toDouble() ?? 0).clamp(
          0,
          100000,
        );
        _gpuTemp = (data['gpu_temp'] as num?)?.toInt() ?? _gpuTemp;

        cpuName = data['cpu_name'] as String? ?? cpuName;
        gpuName = data['gpu_name'] as String? ?? gpuName;
        ramTotal = (data['ram_total'] as num?)?.toInt() ?? ramTotal;

        _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

        _pushHistory(_cpuHistory, _cpuUsage.toDouble());
        _pushHistory(_ramHistory, _ramUsage.toDouble());
        _pushHistory(_diskHistory, _diskUsage.toDouble());
        _pushHistory(_netDownHistory, _downloadSpeed);
        _pushHistory(_netUpHistory, _uploadSpeed);

        _pushHistory(_gpuTempHistory, _gpuTemp.toDouble());

        final cores =
            (data['cores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [];
        _coreUsages = cores;

        while (_coreHistories.length < cores.length) {
          _coreHistories.add([]);
        }

        for (int i = 0; i < cores.length; i++) {
          _pushHistory(_coreHistories[i], cores[i].toDouble());
        }
      });
    } catch (e) {
      debugPrint("fetchStats error: $e");
      _handleFailure();
    }
  }

  void _handleFailure() {
    if (!mounted) return;
    setState(() {
      _failCount++;
      if (_failCount >= 3) _connected = false;
    });
  }

  void _pushHistory(List<double> list, double value) {
    list.add(value);
    if (list.length > 30) list.removeAt(0);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _loadHistory();

    _fetchStats();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ── Mini sparkline ──────────────────────────────────────────────────────
  Widget _sparkline(List<double> data, Color color, {double? fixedMaxY}) {
    final calculatedMax = data.isEmpty
        ? 100.0
        : data.reduce((a, b) => a > b ? a : b) * 1.2;

    final maxY = fixedMaxY ?? calculatedMax.clamp(10, 100000);

    return SizedBox(
      height: 24,
      child: data.length < 2
          ? const SizedBox()
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: color,
                    barWidth: 1.8,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.18),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Skeleton loader ─────────────────────────────────────────────────────
  Widget _skeleton(double w, double h, {double radius = 8}) {
    return _ShimmerBox(width: w, height: h, radius: radius);
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildStatGrid(),
                  const SizedBox(height: 20),
                  if (_coreUsages.isNotEmpty) _buildCoreRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "HardwareMon",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Connection badge
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _connected
                        ? _badge("Live", AppColors.green)
                        : _firstLoad
                        ? _badge("Connecting…", AppColors.orange)
                        : _badge("Offline", AppColors.red),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _firstLoad
                  ? _skeleton(280, 14)
                  : Text(
                      "$cpuName  •  $gpuName  •  $ramTotal GB RAM",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currentTime.isEmpty ? "--:--:--" : _currentTime,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "System clock",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      key: ValueKey(label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    final cards = [
      _StatCardData(
        title: "CPU Usage",
        value: _firstLoad ? null : _cpuUsage,
        prevValue: _prevCpu,
        suffix: "%",
        icon: Icons.memory_rounded,
        color: _usageColor(_cpuUsage),
        history: _cpuHistory,
      ),
      _StatCardData(
        title: "RAM Usage",
        value: _firstLoad ? null : _ramUsage,
        prevValue: _prevRam,
        suffix: "%",
        icon: Icons.storage_rounded,
        color: _usageColor(_ramUsage),
        history: _ramHistory,
      ),
      _StatCardData(
        title: "Disk Usage",
        value: _firstLoad ? null : _diskUsage,
        prevValue: _prevDisk,
        suffix: "%",
        icon: Icons.sd_storage_rounded,
        color: _usageColor(_diskUsage),
        history: _diskHistory,
      ),
      _StatCardData(
        title: "Download",
        value: null,
        prevValue: 0,
        customLabel: _firstLoad
            ? null
            : "${_downloadSpeed.toStringAsFixed(1)} KB/s",
        icon: Icons.download_rounded,
        color: AppColors.blue,
        history: _netDownHistory,
      ),
      _StatCardData(
        title: "Upload",
        value: null,
        prevValue: 0,
        customLabel: _firstLoad
            ? null
            : "${_uploadSpeed.toStringAsFixed(1)} KB/s",
        icon: Icons.upload_rounded,
        color: AppColors.purple,
        history: _netUpHistory,
      ),
      _StatCardData(
        title: "GPU Temp",
        value: _firstLoad ? null : _gpuTemp,
        prevValue: _prevGpuTemp,
        suffix: "°C",
        icon: Icons.thermostat_rounded,
        color: _tempColor(_gpuTemp),
        history:
            _gpuTempHistory, // replace with actual gpu temp history if available
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, i) => _AnimatedStatCard(
        data: cards[i],
        sparkline: _sparkline(cards[i].history, cards[i].color),
        skeleton: _skeleton(double.infinity, double.infinity, radius: 18),
        isLoading: _firstLoad,
      ),
    );
  }

  Widget _buildCoreRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CPU Cores",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _coreUsages.length,
            itemBuilder: (context, index) {
              final usage = _coreUsages[index];
              return _CoreCard(
                index: index,
                usage: usage,
                history: index < _coreHistories.length
                    ? _coreHistories[index]
                    : [],
                sparkline: _sparkline(
                  index < _coreHistories.length ? _coreHistories[index] : [],
                  AppColors.cyan,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Stat card data model ─────────────────────────────────────────────────────
class _StatCardData {
  final String title;
  final int? value;
  final int prevValue;
  final String? customLabel;
  final String? suffix;
  final IconData icon;
  final Color color;
  final List<double> history;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.prevValue,
    required this.icon,
    required this.color,
    required this.history,
    this.customLabel,
    this.suffix,
  });
}

// ─── Animated stat card ───────────────────────────────────────────────────────
class _AnimatedStatCard extends StatefulWidget {
  final _StatCardData data;
  final Widget sparkline;
  final Widget skeleton;
  final bool isLoading;

  const _AnimatedStatCard({
    required this.data,
    required this.sparkline,
    required this.skeleton,
    required this.isLoading,
  });

  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -2.0 : 0.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? widget.data.color.withOpacity(0.5)
                : AppColors.border.withOpacity(0.6),
            width: 1.0,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.data.color.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: widget.isLoading
            ? widget.skeleton
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.data.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.data.icon,
                          size: 16,
                          color: widget.data.color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.data.title,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Animated integer counter (if int value provided)
                            widget.data.value != null
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: widget.data.prevValue.toDouble(),
                                      end: widget.data.value!.toDouble(),
                                    ),
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeOut,
                                    builder: (context, v, _) => Text(
                                      "${v.round()}${widget.data.suffix ?? ''}",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: widget.data.color,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.data.customLabel ?? "—",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: widget.data.color,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  widget.sparkline,
                ],
              ),
      ),
    );
  }
}

// ─── Core card ────────────────────────────────────────────────────────────────
class _CoreCard extends StatelessWidget {
  final int index;
  final int usage;
  final List<double> history;
  final Widget sparkline;

  const _CoreCard({
    required this.index,
    required this.usage,
    required this.history,
    required this.sparkline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Core ${index + 1}",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$usage%",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // Mini usage bar
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: usage / 100),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 3,
                backgroundColor: Colors.white10,
                color: usage >= 85
                    ? AppColors.red
                    : usage >= 65
                    ? AppColors.orange
                    : AppColors.cyan,
              ),
            ),
          ),
          const Spacer(),
          sparkline,
        ],
      ),
    );
  }
}

// ─── Shimmer skeleton ────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFF1C2128),
              Color(0xFF242B35),
              Color(0xFF1C2128),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Processes page ───────────────────────────────────────────────────────────
class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  List<Map<String, dynamic>> _processes = [];
  String _searchQuery = "";
  String _sortBy = "cpu"; // "cpu" | "ram" | "name"
  late Timer _timer;

  Future<void> _checkVirusTotal(int pid) async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:5000/virustotal/process"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"pid": pid}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("VirusTotal Result"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['success'] == true) ...[
                Text("Malicious: ${data['malicious']}"),
                Text("Suspicious: ${data['suspicious']}"),
                Text("Undetected: ${data['undetected']}"),
              ] else ...[
                Text(data['error'] ?? data['message'] ?? "Unknown error"),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("VirusTotal check failed: $e");
    }
  }

  Future<void> _fetchProcesses() async {
    try {
      final result = await Process.run('ps', [
        '-eo',
        'pid,comm,%cpu,%mem',
        '--sort=-%cpu',
      ]);

      final lines = result.stdout
          .toString()
          .split('\n')
          .skip(1)
          .where((l) => l.trim().isNotEmpty)
          .take(60)
          .toList();

      final parsed = <Map<String, dynamic>>[];

      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          parsed.add({
            'pid': parts[0],
            'name': parts[1],
            'cpu': double.tryParse(parts[2]) ?? 0.0,
            'ram': double.tryParse(parts[3]) ?? 0.0,
          });
        }
      }

      if (!mounted) return;
      setState(() => _processes = parsed);
    } catch (e) {
      debugPrint("fetchProcesses error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProcesses();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchProcesses(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchQuery.toLowerCase();
    var list = _processes
        .where(
          (p) =>
              (p['name'] as String).toLowerCase().contains(q) ||
              p['pid'].toString().contains(q),
        )
        .toList();

    switch (_sortBy) {
      case 'cpu':
        list.sort((a, b) => (b['cpu'] as double).compareTo(a['cpu'] as double));
        break;
      case 'ram':
        list.sort((a, b) => (b['ram'] as double).compareTo(a['ram'] as double));
        break;
      case 'name':
        list.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        break;
    }

    return list;
  }

  String _initial(String name) => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Color _cpuColor(double cpu) {
    if (cpu >= 50) return AppColors.red;
    if (cpu >= 20) return AppColors.orange;
    return AppColors.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                "Processes",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${list.length}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Search + sort row
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by name or PID…",
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.border.withOpacity(0.6),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SortChip(
                label: "CPU",
                active: _sortBy == "cpu",
                onTap: () => setState(() => _sortBy = "cpu"),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: "RAM",
                active: _sortBy == "ram",
                onTap: () => setState(() => _sortBy = "ram"),
              ),
              const SizedBox(width: 8),
              _SortChip(
                label: "Name",
                active: _sortBy == "name",
                onTap: () => setState(() => _sortBy = "name"),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: const [
                SizedBox(width: 36),
                SizedBox(width: 12),
                Expanded(child: _ColHeader("Name")),
                SizedBox(width: 70, child: _ColHeader("PID")),
                SizedBox(width: 70, child: _ColHeader("CPU %")),
                SizedBox(width: 70, child: _ColHeader("RAM %")),
              ],
            ),
          ),

          // Process list
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      "No processes found",
                      style: TextStyle(color: Colors.white24),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border.withOpacity(0.3),
                    ),
                    itemBuilder: (context, index) {
                      final proc = list[index];
                      final cpu = proc['cpu'] as double;
                      final ram = proc['ram'] as double;
                      final name = proc['name'] as String;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.013),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _cpuColor(cpu).withOpacity(0.15),
                              child: Text(
                                _initial(name),
                                style: TextStyle(
                                  color: _cpuColor(cpu),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                proc['pid'].toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white38,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                "${cpu.toStringAsFixed(1)}%",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _cpuColor(cpu),
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                "${ram.toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white54,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            GestureDetector(
                              onTap: () => _checkVirusTotal(
                                int.parse(proc['pid'].toString()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.cyan.withOpacity(0.35),
                                  ),
                                ),
                                child: const Text(
                                  "Check VT",
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Colors.white24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.cyan.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.cyan.withOpacity(0.5)
                : AppColors.border.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.cyan : Colors.white38,
          ),
        ),
      ),
    );
  }
}

// ─── Settings page ────────────────────────────────────────────────────────────
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),

          _SettingsSection(
            title: "Appearance",
            children: [
              _SettingsTile(
                icon: Icons.refresh_rounded,
                title: "Refresh rate",
                subtitle: "How often stats are fetched",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    "2 seconds",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsSection(
            title: "About",
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: "HardwareMon",
                subtitle: "Cross-platform hardware monitor",
                trailing: const Text(
                  'v$_kAppVersion',
                  style: TextStyle(fontSize: 13, color: Colors.white24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white24,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withOpacity(0.6)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
