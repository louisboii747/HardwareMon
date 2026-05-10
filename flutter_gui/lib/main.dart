import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  final List<Widget> pages = [
    const DashboardPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 90,
            color: const Color(0xFF11151C),
            child: Column(
              children: [
                const SizedBox(height: 30),

                const Icon(
                  Icons.memory,
                  size: 40,
                ),

                const SizedBox(height: 40),

                IconButton(
                  icon: Icon(
                    Icons.dashboard,
                    size: 30,
                    color: selectedPage == 0
                        ? Colors.cyanAccent
                        : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedPage = 0;
                    });
                  },
                ),

                const SizedBox(height: 20),

                IconButton(
                  icon: Icon(
                    Icons.settings,
                    size: 30,
                    color: selectedPage == 1
                        ? Colors.cyanAccent
                        : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedPage = 1;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: pages[selectedPage],
          ),
        ],
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

  late Timer timer;

  Future<void> fetchStats() async {
    try {
      final result = await Process.run(
        'python',
        ['../hardwaremon/api.py'],
      );

      final data = jsonDecode(result.stdout);

      setState(() {
        cpuUsage = data['cpu'];
        ramUsage = data['ram'];
        diskUsage = data['disk'];
      });
    } catch (e) {
      print("Error fetching stats: $e");
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            "HardwareMon",
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "Modern Hardware Monitoring",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 40),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.2,

              children: [
                StatCard(
                  title: "CPU Usage",
                  value: "$cpuUsage%",
                  icon: Icons.memory,
                ),

                StatCard(
                  title: "RAM Usage",
                  value: "$ramUsage%",
                  icon: Icons.storage,
                ),

                StatCard(
                  title: "Disk Usage",
                  value: "$diskUsage%",
                  icon: Icons.sd_storage,
                ),

                const StatCard(
                  title: "Backend",
                  value: "Connected",
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        transform: Matrix4.identity()
          ..scale(hovered ? 1.03 : 1.0),

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: const Color(0xFF161B22),

          borderRadius: BorderRadius.circular(20),

          border: Border.all(
            color: hovered
                ? Colors.cyanAccent
                : Colors.white10,
            width: 1.5,
          ),

          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),

        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 40,
              color: hovered
                  ? Colors.cyanAccent
                  : Colors.white,
            ),

            const SizedBox(width: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  widget.value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(30),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            "Settings",
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 20),

          Text(
            "HardwareMon settings will appear here.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}