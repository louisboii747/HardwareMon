import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_point.dart';

class CpuHistoryChart extends StatelessWidget {
  final List<HistoryPoint> history;

  const CpuHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final orderedHistory = history.reversed.toList();
    final spots = orderedHistory.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.cpuPercent);
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,

          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,

                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= orderedHistory.length) {
                    return const SizedBox();
                  }

                  // only show every 20th label
                  final labelInterval = (orderedHistory.length / 5).ceil();

                  if (index % labelInterval != 0) {
                    return const SizedBox();
                  }

                  final timestamp = orderedHistory[index].timestamp;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('HH:mm').format(timestamp),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),

          lineBarsData: [LineChartBarData(spots: spots, isCurved: true)],
        ),
      ),
    );
  }
}
