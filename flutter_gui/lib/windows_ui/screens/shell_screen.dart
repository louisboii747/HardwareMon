import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/glass_panel.dart';
import '../widgets/metric_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'pages/dashboard_page.dart';
import 'pages/performance_page.dart';
import 'pages/processes_page.dart';
import 'pages/settings_page.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int cpuUsage = 0;
  int ramUsage = 0;
  int gpuTemp = 0;

  int selectedIndex = 0;

  String cpuName = 'Loading...';

  List<double> cpuHistory = [];
  List<double> ramHistory = [];
  List<double> gpuTempHistory = [];

  Timer? timer;

  Future<void> fetchStats() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/stats'));

      final data = jsonDecode(response.body);

      setState(() {
        cpuUsage = data['cpu'] ?? 0;
        ramUsage = data['ram'] ?? 0;
        gpuTemp = data['gpu_temp'] ?? 0;

        cpuHistory.add(cpuUsage.toDouble());
        ramHistory.add(ramUsage.toDouble());
        gpuTempHistory.add(gpuTemp.toDouble());

        if (cpuHistory.length > 30) {
          cpuHistory.removeAt(0);
        }

        if (ramHistory.length > 30) {
          ramHistory.removeAt(0);
        }

        if (gpuTempHistory.length > 30) {
          gpuTempHistory.removeAt(0);
        }

        cpuName = data['cpu_name'] ?? 'Unknown CPU';
      });
    } catch (e) {
      debugPrint('Failed to fetch stats: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    fetchStats();

    timer = Timer.periodic(const Duration(seconds: 1), (_) => fetchStats());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget buildDashboard() {
    return Row(
      children: [
        Expanded(
          flex: 2,

          child:
              MetricCard(
                    title: 'CPU Usage',
                    value: '$cpuUsage%',
                    subtitle: cpuName,
                    icon: Icons.memory_rounded,
                    accent: Colors.cyan,
                    graphPoints: cpuHistory,
                  )
                  .animate()
                  .fadeIn(duration: 700.ms, curve: Curves.easeOutCubic)
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                  ),
        ),

        const SizedBox(width: 24),

        Expanded(
          child: Column(
            children: [
              Expanded(
                child:
                    MetricCard(
                          title: 'Memory',
                          value: '$ramUsage%',
                          subtitle: 'System memory usage',
                          icon: Icons.storage_rounded,
                          accent: Colors.purple,
                          graphPoints: ramHistory,
                        )
                        .animate()
                        .fadeIn(delay: 120.ms, duration: 700.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 700.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child:
                    MetricCard(
                          title: 'GPU Temp',
                          value: '$gpuTemp°',
                          subtitle: 'Live telemetry',
                          icon: Icons.graphic_eq_rounded,
                          accent: Colors.orange,
                          graphPoints: gpuTempHistory,
                        )
                        .animate()
                        .fadeIn(delay: 220.ms, duration: 700.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 700.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget getCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return buildDashboard();

      case 1:
        return const ProcessesPage();

      case 2:
        return const PerformancePage();

      case 3:
        return const SettingsPage();

      default:
        return buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: [Color(0xFF050505), Color(0xFF090909), Color(0xFF04070D)],
          ),
        ),

        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -120,

              child: Container(
                width: 400,
                height: 400,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  gradient: RadialGradient(
                    colors: [Colors.cyan.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Row(
                  children: [
                    SizedBox(
                      width: 88,

                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(vertical: 20),

                        child: Column(
                          children: [
                            const Icon(
                              Icons.memory_rounded,
                              color: Colors.white,
                              size: 28,
                            ),

                            const SizedBox(height: 32),

                            _DockItem(
                              icon: Icons.dashboard_rounded,
                              active: selectedIndex == 0,

                              onTap: () {
                                setState(() {
                                  selectedIndex = 0;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            _DockItem(
                              icon: Icons.list_rounded,
                              active: selectedIndex == 1,

                              onTap: () {
                                setState(() {
                                  selectedIndex = 1;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            _DockItem(
                              icon: Icons.analytics_rounded,
                              active: selectedIndex == 2,

                              onTap: () {
                                setState(() {
                                  selectedIndex = 2;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            _DockItem(
                              icon: Icons.settings_rounded,
                              active: selectedIndex == 3,

                              onTap: () {
                                setState(() {
                                  selectedIndex = 3;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const SizedBox(height: 8),

                          const Text(
                            'HardwareMon',

                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 450),

                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,

                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,

                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.03, 0),
                                      end: Offset.zero,
                                    ).animate(animation),

                                    child: child,
                                  ),
                                );
                              },

                              child: KeyedSubtree(
                                key: ValueKey(selectedIndex),
                                child: getCurrentPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),

      child: GestureDetector(
        onTap: widget.onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          width: 52,
          height: 52,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            color: widget.active || hovering
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,

            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.18),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),

          child: Icon(
            widget.icon,
            color: widget.active ? Colors.white : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
