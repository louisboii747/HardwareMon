import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService settingsService = SettingsService();
  AppSettings settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await settingsService.loadSettings();

    setState(() {
      settings = loadedSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
            ),
          ),

          const SizedBox(height: 24),

          _buildSection('General', [
            _settingRow(
              'Theme',
              DropdownButton<String>(
                value: settings.theme,
                items: const [
                  DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'Light', child: Text('Light')),
                ],
                onChanged: (value) async {
                  final updatedSettings = settings.copyWith(theme: value!);

                  setState(() {
                    settings = updatedSettings;
                  });

                  await settingsService.saveSettings(updatedSettings);
                },
              ),
            ),

            _settingRow(
              'Launch on Startup',
              Switch(
                value: settings.launchOnStartup,
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(launchOnStartup: value);
                  });
                },
              ),
            ),

            _settingRow(
              'Minimise to Tray',
              Switch(
                value: settings.minimiseToTray,
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(minimiseToTray: value);
                  });
                },
              ),
            ),

            _settingRow(
              'Close to Tray',
              Switch(
                value: settings.closeToTray,
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(closeToTray: value);
                  });
                },
              ),
            ),
          ]),

          _buildSection('Monitoring', [
            _settingRow(
              'Refresh Interval',
              DropdownButton<String>(
                value: settings.refreshInterval,
                items: const [
                  DropdownMenuItem(value: '1s', child: Text('1 second')),
                  DropdownMenuItem(value: '2s', child: Text('2 seconds')),
                  DropdownMenuItem(value: '5s', child: Text('5 seconds')),
                ],
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(refreshInterval: value!);
                  });
                },
              ),
            ),

            _buildSection('Notifications', [
              _settingRow(
                'CPU Alerts',
                Switch(
                  value: settings.cpuAlerts,
                  onChanged: (value) {
                    setState(() {
                      settings = settings.copyWith(cpuAlerts: value);
                    });
                  },
                ),
              ),

              _settingRow(
                'RAM Alerts',
                Switch(
                  value: settings.ramAlerts,
                  onChanged: (value) {
                    setState(() {
                      settings = settings.copyWith(ramAlerts: value);
                    });
                  },
                ),
              ),

              _settingRow(
                'Temperature Alerts',
                Switch(
                  value: settings.temperatureAlerts,
                  onChanged: (value) {
                    setState(() {
                      settings = settings.copyWith(temperatureAlerts: value);
                    });
                  },
                ),
              ),

              _settingRow(
                'Alert Sounds',
                Switch(
                  value: settings.alertSounds,
                  onChanged: (value) {
                    setState(() {
                      settings = settings.copyWith(alertSounds: value);
                    });
                  },
                ),
              ),
            ]),

            _buildSection('Updates', [
              _settingRow(
                'Auto Update Checks',
                Switch(
                  value: settings.autoUpdateChecks,
                  onChanged: (value) {
                    setState(() {
                      settings = settings.copyWith(autoUpdateChecks: value);
                    });
                  },
                ),
              ),

              _settingRow('Current Version', const Text('0.1.0')),

              _settingRow(
                'Check for Updates',
                ElevatedButton(onPressed: () {}, child: const Text('Check')),
              ),
            ]),

            _buildSection('Advanced', [
              _settingRow(
                'Open Logs Folder',
                ElevatedButton(onPressed: () {}, child: const Text('Open')),
              ),

              _settingRow(
                'Export Diagnostics',
                ElevatedButton(onPressed: () {}, child: const Text('Export')),
              ),

              _settingRow(
                'Reset Settings',
                ElevatedButton(onPressed: () {}, child: const Text('Reset')),
              ),
            ]),

            _buildSection('About', [
              _settingRow('Version', const Text('0.1.0')),

              _settingRow('Platform', const Text('Windows / Linux')),

              _settingRow('Backend', const Text('FastAPI')),

              _settingRow('Telemetry', const Text('LibreHardwareMonitor')),
            ]),

            _settingRow(
              'Historical Monitoring',
              Switch(
                value: settings.historicalMonitoring,
                onChanged: (value) {
                  setState(() {
                    settings = settings.copyWith(historicalMonitoring: value);
                  });
                },
              ),
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

  Widget _settingRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
          trailing,
        ],
      ),
    );
  }
}
