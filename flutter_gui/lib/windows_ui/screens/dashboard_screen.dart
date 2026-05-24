import 'package:flutter/material.dart';
import '../widgets/expandable_metric_card.dart';
import '../../services/api_service.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/animated_metric_value.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double cpuUsage = 0;
  double ramUsage = 0;
  double gpuTemp = 0;

  List<double> cpuHistory = [12, 18, 24, 22, 35, 42, 38, 51, 46, 58, 62, 54];

  List<double> ramHistory = [42, 44, 46, 48, 47, 49, 51, 50, 52, 53, 54, 55];

  List<double> gpuTempHistory = [48, 49, 50, 51, 52, 53, 54];

  @override
  void initState() {
    super.initState();

    loadSystemStats();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      loadSystemStats();
    });
  }

  Future<void> loadSystemStats() async {
    try {
      final data = await ApiService.fetchSystemStats();

      print(data);

      setState(() {
        cpuUsage = (data['cpu'] ?? 0).toDouble();
        ramUsage = (data['ram'] ?? 0).toDouble();
        gpuTemp = (data['gpu_temp'] ?? 0).toDouble();

        cpuHistory.add(cpuUsage);
        ramHistory.add(ramUsage);
        gpuTempHistory.add(gpuTemp);

        if (cpuHistory.length > 30) {
          cpuHistory.removeAt(0);
        }

        if (ramHistory.length > 30) {
          ramHistory.removeAt(0);
        }

        if (gpuTempHistory.length > 30) {
          gpuTempHistory.removeAt(0);
        }
      });
    } catch (e) {
      print('Failed to fetch stats: $e');
    }
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required List<double> points,
    required Color accent,
    required bool isTemperature,
    required String metricKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: Colors.white.withOpacity(0.04)),

        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,

              builder: (context, valueAnim, child) {
                return Opacity(
                  opacity: valueAnim,

                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - valueAnim)),
                    child: child,
                  ),
                );
              },

              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: points.length.toDouble() - 1,

                  minY: points.reduce((a, b) => a < b ? a : b) - 5,

                  maxY: points.reduce((a, b) => a > b ? a : b) + 5,

                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),

                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        points.length,
                        (i) => FlSpot(i.toDouble(), points[i]),
                      ),

                      isCurved: true,
                      curveSmoothness: 0.45,
                      preventCurveOverShooting: true,

                      color: accent,
                      barWidth: 4,
                      isStrokeCapRound: true,

                      dotData: const FlDotData(show: false),

                      belowBarData: BarAreaData(
                        show: true,

                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,

                          colors: [
                            accent.withOpacity(0.25),
                            accent.withOpacity(0.01),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            title,

            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          AnimatedMetricValue(
            key: ValueKey(metricKey),
            value: value,
            isTemperature: isTemperature,
          ),
        ],
      ),
    );
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

            Padding(
              padding: const EdgeInsets.all(40),

              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.25,

                children: [
                  ExpandableMetricCard(
                    title: 'CPU',
                    value: '${cpuUsage.toStringAsFixed(0)}%',
                    subtitle: 'Realtime processor utilisation',
                    icon: Icons.memory_rounded,
                    accent: Colors.cyan,
                    graphPoints: cpuHistory,

                    closedChild: _buildMetricCard(
                      title: 'CPU Usage',
                      value: cpuUsage,
                      points: cpuHistory,
                      accent: Colors.cyan,
                      isTemperature: false,
                      metricKey: 'cpuMetric',
                    ),
                  ),

                  ExpandableMetricCard(
                    title: 'RAM',
                    value: '${ramUsage.toStringAsFixed(0)}%',
                    subtitle: 'System memory utilisation',
                    icon: Icons.storage_rounded,
                    accent: Colors.purpleAccent,
                    graphPoints: ramHistory,

                    closedChild: _buildMetricCard(
                      title: 'RAM Usage',
                      value: ramUsage,
                      points: ramHistory,
                      accent: Colors.purpleAccent,
                      isTemperature: false,
                      metricKey: 'ramMetric',
                    ),
                  ),

                  ExpandableMetricCard(
                    title: 'GPU TEMP',
                    value: '${gpuTemp.toStringAsFixed(0)}°C',
                    subtitle: 'Graphics processor temperature',
                    icon: Icons.graphic_eq_rounded,
                    accent: Colors.orangeAccent,
                    graphPoints: gpuTempHistory,

                    closedChild: _buildMetricCard(
                      title: 'GPU Temperature',
                      value: gpuTemp,
                      points: gpuTempHistory,
                      accent: Colors.orangeAccent,
                      isTemperature: true,
                      metricKey: 'gpuMetric',
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
