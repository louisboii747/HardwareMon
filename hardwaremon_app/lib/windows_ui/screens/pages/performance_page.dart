import 'package:flutter/material.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/metric_card.dart';

class PerformancePage extends StatelessWidget {
  final TelemetryService telemetry;

  const PerformancePage({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
            ),
          ),

          const SizedBox(height: 24),

          _buildSection(context, 'CPU', [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                MetricCard(
                  title: 'CPU Usage',
                  value: '${telemetry.cpuUsage}%',
                  subtitle: telemetry.cpuName,
                  icon: Icons.memory_rounded,
                  accent: Colors.cyan,
                  graphPoints: telemetry.cpuHistory,
                ),
                MetricCard(
                  title: 'CPU Temperature',
                  value: '${telemetry.cpuTemp}°C',
                  subtitle: 'CPU Package Temperature',
                  icon: Icons.thermostat_rounded,
                  accent: Colors.red,
                  graphPoints: telemetry.cpuHistory,
                ),
                MetricCard(
                  title: 'CPU Clock',
                  value: '${telemetry.cpuClockGHz.toStringAsFixed(2)} GHz',
                  subtitle: 'Current clock speed',
                  icon: Icons.speed_rounded,
                  accent: Colors.green,
                  graphPoints: telemetry.cpuHistory,
                ),
                MetricCard(
                  title: 'CPU Power',
                  value: '${telemetry.cpuPower.toStringAsFixed(1)} W',
                  subtitle: 'Package power draw',
                  icon: Icons.bolt_rounded,
                  accent: Colors.amber,
                  graphPoints: telemetry.cpuHistory,
                ),
              ],
            ),
          ]),

          _buildSection(context, 'Memory', [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                MetricCard(
                  title: 'RAM Usage',
                  value: '${telemetry.ramUsage}%',
                  subtitle: 'System memory usage',
                  icon: Icons.storage_rounded,
                  accent: Colors.purple,
                  graphPoints: telemetry.ramHistory,
                ),

                MetricCard(
                  title: 'RAM Used',
                  value: '${telemetry.ramUsed.toStringAsFixed(1)} GB',
                  subtitle: 'Currently allocated',
                  icon: Icons.memory_rounded,
                  accent: Colors.teal,
                  graphPoints: telemetry.ramHistory,
                ),

                MetricCard(
                  title: 'RAM Available',
                  value: '${telemetry.ramAvailable.toStringAsFixed(1)} GB',
                  subtitle: 'Available memory',
                  icon: Icons.check_circle_outline_rounded,
                  accent: Colors.lightGreen,
                  graphPoints: telemetry.ramHistory,
                ),

                MetricCard(
                  title: 'Total RAM',
                  value: '${telemetry.ramTotal.toStringAsFixed(1)} GB',
                  subtitle: 'Installed memory',
                  icon: Icons.dns_rounded,
                  accent: Colors.indigo,
                  graphPoints: telemetry.ramHistory,
                ),
              ],
            ),
          ]),

          _buildSection(context, 'GPU', [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                MetricCard(
                  title: 'GPU Temperature',
                  value: '${telemetry.gpuTemp}°C',
                  subtitle: 'Live telemetry',
                  icon: Icons.graphic_eq_rounded,
                  accent: Colors.orange,
                  graphPoints: telemetry.gpuTempHistory,
                ),

                MetricCard(
                  title: 'GPU Usage',
                  value: '${telemetry.gpuUsage}%',
                  subtitle: 'Current GPU load',
                  icon: Icons.show_chart_rounded,
                  accent: Colors.blue,
                  graphPoints: telemetry.gpuTempHistory,
                ),

                MetricCard(
                  title: 'GPU Power',
                  value: '${telemetry.gpuPower.toStringAsFixed(1)} W',
                  subtitle: 'Board power draw',
                  icon: Icons.bolt_rounded,
                  accent: const Color.fromARGB(255, 115, 255, 0),
                  graphPoints: telemetry.gpuTempHistory,
                ),

                MetricCard(
                  title: 'VRAM Used',
                  value: '${telemetry.gpuVramUsed.toStringAsFixed(1)} GB',
                  subtitle: 'Graphics memory usage',
                  icon: Icons.memory_rounded,
                  accent: Colors.purple,
                  graphPoints: telemetry.gpuTempHistory,
                ),
              ],
            ),
          ]),

          _buildSection(context, 'Historical Analytics', [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                MetricCard(
                  title: 'CPU History',
                  value: '${telemetry.historicalCpuHistory.length}',
                  subtitle: 'Samples collected',
                  icon: Icons.timeline_rounded,
                  accent: Colors.cyan,
                  graphPoints: telemetry.historicalCpuHistory,
                ),
                MetricCard(
                  title: 'Memory History',
                  value: '${telemetry.historicalRamHistory.length}',
                  subtitle: 'Samples collected',
                  icon: Icons.storage_rounded,
                  accent: Colors.purple,
                  graphPoints: telemetry.historicalRamHistory,
                ),

                MetricCard(
                  title: 'GPU History',
                  value: '${telemetry.historicalGpuHistory.length}',
                  subtitle: 'Samples collected',
                  icon: Icons.graphic_eq_rounded,
                  accent: Colors.orange,
                  graphPoints: telemetry.historicalGpuHistory,
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }
}
