import 'package:flutter/material.dart';
import '../widgets/expandable_metric_card.dart';
import '../../services/api_service.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double cpuUsage = 0;

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
        cpuUsage = (data['cpu_usage'] ?? 0).toDouble();
      });
    } catch (e) {
      print('Failed to fetch stats: $e');
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
            Center(
              child: SizedBox(
                width: 420,
                child: ExpandableMetricCard(
                  title: 'CPU',
                  closedChild: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SizedBox(
                      height: 220,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CPU Usage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${cpuUsage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
