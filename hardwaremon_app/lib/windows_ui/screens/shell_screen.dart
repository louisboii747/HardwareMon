import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/glass_panel.dart';
import '../widgets/metric_card.dart';
import 'pages/performance_page.dart';
import 'pages/processes_page.dart';
import 'pages/settings_page.dart';
import '../services/telemetry_service.dart';
import '../core/theme/app_colors.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late TelemetryService telemetry;

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    telemetry = TelemetryService();

    telemetry.start();

    telemetry.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    telemetry.stop();
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
                    value: '${telemetry.cpuUsage}%',
                    subtitle: telemetry.cpuName,
                    icon: Icons.memory_rounded,
                    accent: Colors.cyan,
                    graphPoints: telemetry.cpuHistory,
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
                          value: '${telemetry.ramUsage}%',
                          subtitle: 'System memory usage',
                          icon: Icons.storage_rounded,
                          accent: Colors.purple,
                          graphPoints: telemetry.ramHistory,
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
                          value: '${telemetry.gpuTemp}°',
                          subtitle: 'Live telemetry',
                          icon: Icons.graphic_eq_rounded,
                          accent: Colors.orange,
                          graphPoints: telemetry.gpuTempHistory,
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
        return PerformancePage(telemetry: telemetry);

      case 3:
        return SettingsPage(telemetry: telemetry);

      default:
        return buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: AppColors.pageGradient(context),
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
                    colors: [
                      Colors.cyan.withValues(
                        alpha: AppColors.isLight(context) ? 0.12 : 0.08,
                      ),
                      Colors.transparent,
                    ],
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
                              color: AppColors.accent,
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
    final activeColor = AppColors.textPrimary(context);
    final inactiveColor = AppColors.textSecondary(context);

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
                ? AppColors.overlay(context, 0.08)
                : Colors.transparent,

            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.18),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),

          child: Icon(
            widget.icon,
            color: widget.active ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}
