import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/history_point.dart';

class CpuHistoryChart extends StatelessWidget {
  final List<HistoryPoint> history;

  const CpuHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.cpuPercent);
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineBarsData: [LineChartBarData(spots: spots, isCurved: true)],
        ),
      ),
    );
  }
}
