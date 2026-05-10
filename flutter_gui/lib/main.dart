import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

String cpuName = "Loading...";
String gpuName = "Loading...";
int ramTotal = 0;

void main() {
  runApp(const HardwareMonApp());
}

class HardwareMonApp extends StatelessWidget {
  const HardwareMonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HardwareMon',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const ProcessesPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 95,
            color: const Color(0xFF11151C),
            child: Column(
              children: [
                const SizedBox(height: 30),

                TweenAnimationBuilder(
                  tween: Tween(begin: 0.7, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.memory_rounded,
                    size: 42,
                    color: Colors.cyanAccent,
                  ),
                ),

                const SizedBox(height: 45),

                sidebarButton(
                  icon: Icons.dashboard_rounded,
                  active: selectedPage == 0,
                  onPressed: () {
                    setState(() {
                      selectedPage = 0;
                    });
                  },
                ),

                const SizedBox(height: 22),

                sidebarButton(
                  icon: Icons.list_alt_rounded,
                  active: selectedPage == 1,
                  onPressed: () {
                    setState(() {
                      selectedPage = 1;
                    });
                  },
                ),

                const SizedBox(height: 22),

                sidebarButton(
                  icon: Icons.settings_rounded,
                  active: selectedPage == 2,
                  onPressed: () {
                    setState(() {
                      selectedPage = 2;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: pages[selectedPage],
            ),
          ),
        ],
      ),
    );
  }

  Widget sidebarButton({
    required IconData icon,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active
            ? Colors.cyanAccent.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  blurRadius: 18,
                ),
              ]
            : [],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 30,
          color: active ? Colors.cyanAccent : Colors.white70,
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int cpuUsage = 0;
  int ramUsage = 0;
  int diskUsage = 0;

  double uploadSpeed = 0;
  double downloadSpeed = 0;

  int gpuTemp = 0;

  String currentTime = "";
  String uptime = "";

  List<double> cpuHistory = [];
  List<double> ramHistory = [];
  List<double> networkHistory = [];

  List<List<double>> coreHistories = [];
  List<int> coreUsages = [];

  late Timer timer;

  Color getTempColor(int temp) {
    if (temp >= 85) {
      return Colors.redAccent;
    }

    if (temp >= 70) {
      return Colors.orangeAccent;
    }

    return Colors.greenAccent;
  }

  Future<void> fetchStats() async {
  try {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/stats'),
    );

    final data = jsonDecode(response.body);

    if (!mounted) return;

    setState(() {
      final cores = (data['cores'] as List)
          .map((e) => (e as num).toInt())
          .toList();

      cpuUsage = data['cpu'] ?? 0;
      coreUsages = cores;

      ramUsage = data['ram'] ?? 0;
      diskUsage = data['disk'] ?? 0;

      cpuName = data['cpu_name'] ?? "Unknown CPU";
      gpuName = data['gpu_name'] ?? "Unknown GPU";

      ramTotal = data['ram_total'] ?? 0;

      uploadSpeed =
          (data['upload'] ?? 0).toDouble();

      downloadSpeed =
          (data['download'] ?? 0).toDouble();

      gpuTemp = data['gpu_temp'] ?? 0;

      currentTime =
          DateFormat('HH:mm:ss').format(DateTime.now());

      uptime = "Online";

      cpuHistory.add(cpuUsage.toDouble());
      ramHistory.add(ramUsage.toDouble());
      networkHistory.add(downloadSpeed);

      while (
          coreHistories.length < coreUsages.length) {
        coreHistories.add([]);
      }

      for (int i = 0;
          i < coreUsages.length;
          i++) {
        coreHistories[i]
            .add(coreUsages[i].toDouble());

        if (coreHistories[i].length > 30) {
          coreHistories[i].removeAt(0);
        }
      }

      if (cpuHistory.length > 30) {
        cpuHistory.removeAt(0);
      }

      if (ramHistory.length > 30) {
        ramHistory.removeAt(0);
      }

      if (networkHistory.length > 30) {
        networkHistory.removeAt(0);
      }
    });
  } catch (e) {
    print("API error: $e");
  }
}

  @override
  void initState() {
    super.initState();

    fetchStats();

    timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchStats(),
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Widget buildMiniGraph(
    List<double> data,
    Color color,
  ) {
    return SizedBox(
      height: 22,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      e.value,
                    ),
                  )
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.35,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 15 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HardwareMon",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "$cpuName • $gpuName • ${ramTotal} GB RAM",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      currentTime,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      uptime,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: 1250,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: "CPU Usage",
                              value: "$cpuUsage%",
                              icon: Icons.memory_rounded,
                              graph: buildMiniGraph(
                                cpuHistory,
                                Colors.cyanAccent,
                              ),
                            ),
                          ),

                          const SizedBox(width: 18),

                          Expanded(
                            child: StatCard(
                              title: "RAM Usage",
                              value: "$ramUsage%",
                              icon: Icons.storage_rounded,
                              graph: buildMiniGraph(
                                ramHistory,
                                Colors.greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: "Disk Usage",
                              value: "$diskUsage%",
                              icon: Icons.sd_storage_rounded,
                              graph: buildMiniGraph(
                                cpuHistory,
                                Colors.orangeAccent,
                              ),
                            ),
                          ),

                          const SizedBox(width: 18),

                          Expanded(
                            child: StatCard(
                              title: "Download",
                              value:
                                  "${downloadSpeed.toStringAsFixed(1)} KB/s",
                              icon: Icons.download_rounded,
                              graph: buildMiniGraph(
                                networkHistory,
                                Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: "Upload",
                              value:
                                  "${uploadSpeed.toStringAsFixed(1)} KB/s",
                              icon: Icons.upload_rounded,
                              graph: buildMiniGraph(
                                networkHistory,
                                Colors.purpleAccent,
                              ),
                            ),
                          ),

                          const SizedBox(width: 18),

                          Expanded(
                            child: StatCard(
                              title: "GPU Temp",
                              value: "$gpuTemp°C",
                              icon: Icons.videogame_asset_rounded,
                              graph: buildMiniGraph(
                                cpuHistory,
                                getTempColor(gpuTemp),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: coreUsages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(
                              right: 14,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF161B22),
                              borderRadius:
                                  BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Core ${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  "${coreUsages[index]}%",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const Spacer(),

                                buildMiniGraph(
                                  coreHistories[index],
                                  Colors.cyanAccent,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius:
                              BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "CPU History",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: 100,
                                  gridData:
                                      const FlGridData(
                                    show: false,
                                  ),
                                  titlesData:
                                      const FlTitlesData(
                                    show: false,
                                  ),
                                  borderData:
                                      FlBorderData(
                                    show: false,
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: cpuHistory
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => FlSpot(
                                              e.key
                                                  .toDouble(),
                                              e.value,
                                            ),
                                          )
                                          .toList(),
                                      isCurved: true,
                                      curveSmoothness:
                                          0.35,
                                      color:
                                          Colors.cyanAccent,
                                      barWidth: 3,
                                      dotData:
                                          const FlDotData(
                                        show: false,
                                      ),
                                      belowBarData:
                                          BarAreaData(
                                        show: true,
                                        color: Colors
                                            .cyanAccent
                                            .withOpacity(
                                          0.10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Widget graph;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.graph,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.cyanAccent,
                size: 22,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          graph,
        ],
      ),
    );
  }
}

class ProcessesPage extends StatelessWidget {
  const ProcessesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Processes Page",
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Settings Page",
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
        ),
      ),
    );
  }
}