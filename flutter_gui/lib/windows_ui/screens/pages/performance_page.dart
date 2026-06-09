import 'package:flutter/material.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';
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

          _buildSection('CPU', [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                SizedBox(
                  height: 240,
                  child: MetricCard(
                    title: 'CPU Usage',
                    value: '${telemetry.cpuUsage}%',
                    subtitle: telemetry.cpuName,
                    icon: Icons.memory_rounded,
                    accent: Colors.cyan,
                    graphPoints: telemetry.cpuHistory,
                  ),
                ),

                MetricCard(
                  title: 'CPU Temperature',
                  value: '${telemetry.cpuTemp}°C',
                  subtitle: 'CPU Package Temperature',
                  icon: Icons.thermostat_rounded,
                  accent: Colors.red,
                  graphPoints: telemetry.cpuHistory,
                ),
              ],
            ),
          ]),

          MetricCard(
            title: 'Memory',
            value: '${telemetry.ramUsage}%',
            subtitle: 'System memory usage',
            icon: Icons.storage_rounded,
            accent: Colors.purple,
            graphPoints: telemetry.ramHistory,
          ),

          _buildSection('GPU', [
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
                  title: 'GPU History',
                  value: '${telemetry.gpuTempHistory.length}',
                  subtitle: 'Historical GPU temperatures',
                  icon: Icons.history_rounded,
                  accent: Colors.blue,
                  graphPoints: telemetry.gpuTempHistory,
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  Widget _metricCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }
}
