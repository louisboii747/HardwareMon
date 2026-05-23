import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/glass_panel.dart';
import '../widgets/metric_card.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

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
            // Ambient glow
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
                    // Sidebar
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

                            const _DockItem(
                              icon: Icons.dashboard_rounded,
                              active: true,
                            ),

                            const SizedBox(height: 12),

                            const _DockItem(icon: Icons.analytics_rounded),

                            const SizedBox(height: 12),

                            const _DockItem(icon: Icons.settings_rounded),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Main area
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
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,

                                  child:
                                      const MetricCard(
                                            title: 'CPU Usage',
                                            value: '24%',
                                            subtitle:
                                                'Ryzen 7 5800X • 12 threads active',
                                            icon: Icons.memory_rounded,
                                            accent: Colors.cyan,
                                          )
                                          .animate()
                                          .fadeIn(
                                            duration: 700.ms,
                                            curve: Curves.easeOutCubic,
                                          )
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
                                            const MetricCard(
                                                  title: 'Memory',
                                                  value: '18GB',
                                                  subtitle:
                                                      '48GB total • 37% usage',
                                                  icon: Icons.storage_rounded,
                                                  accent: Colors.purple,
                                                )
                                                .animate()
                                                .fadeIn(
                                                  delay: 120.ms,
                                                  duration: 700.ms,
                                                )
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
                                            const MetricCard(
                                                  title: 'GPU Temp',
                                                  value: '61°',
                                                  subtitle:
                                                      'RTX 2070 • Stable thermal load',
                                                  icon:
                                                      Icons.graphic_eq_rounded,
                                                  accent: Colors.orange,
                                                )
                                                .animate()
                                                .fadeIn(
                                                  delay: 220.ms,
                                                  duration: 700.ms,
                                                )
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

  const _DockItem({required this.icon, this.active = false});

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

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        width: 52,
        height: 52,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),

          color: widget.active || hovering
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
        ),

        child: Icon(
          widget.icon,
          color: widget.active ? Colors.white : Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}
