import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/app_settings.dart';
import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';
import 'package:flutter_gui/windows_ui/models/dashboard_preferences.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/widgets/command_palette.dart';
import 'package:flutter_gui/windows_ui/widgets/metric_alert_action.dart';
import 'package:flutter_gui/windows_ui/widgets/metric_card.dart';
import 'package:flutter_gui/windows_ui/widgets/telemetry_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system condition highlights headroom and pressure', () {
    final coasting = evaluateSystemCondition(
      cpuUsage: 12,
      ramUsage: 20,
      cpuTemperature: 42,
      gpuTemperature: 45,
      paused: false,
      hasError: false,
    );
    final pressured = evaluateSystemCondition(
      cpuUsage: 97,
      ramUsage: 70,
      cpuTemperature: 64,
      gpuTemperature: 71,
      paused: false,
      hasError: false,
    );

    expect(coasting.label, 'Coasting');
    expect(pressured.label, 'Under pressure');
  });

  testWidgets('command palette searches and runs a matching action', (
    tester,
  ) async {
    var snapshotCopied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showHardwareMonCommandPalette(
                  context: context,
                  systemSummary: 'Balanced · System looks healthy',
                  telemetrySummary: 'CPU 20% · RAM 40% · GPU 55°',
                  systemColor: Colors.greenAccent,
                  actions: [
                    const CommandPaletteAction(
                      id: 'dashboard',
                      title: 'Open Dashboard',
                      description: 'Return to the overview',
                      section: 'Navigate',
                      icon: Icons.dashboard_rounded,
                      run: _noop,
                    ),
                    CommandPaletteAction(
                      id: 'copy',
                      title: 'Copy Live System Snapshot',
                      description: 'Copy a diagnostic summary',
                      section: 'Quick actions',
                      icon: Icons.copy_rounded,
                      run: () => snapshotCopied = true,
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'snapshot');
    await tester.pump();

    expect(find.text('Copy Live System Snapshot'), findsOneWidget);
    expect(find.text('Open Dashboard'), findsNothing);

    await tester.tap(find.text('Copy Live System Snapshot'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(snapshotCopied, isTrue);
  });

  test('dashboard workspace persists across app sessions', () async {
    SharedPreferences.setMockInitialValues({});

    final preferences = DashboardPreferences();
    await preferences.setWorkspace(DashboardWorkspace.thermals);

    final restored = DashboardPreferences();
    await restored.load();

    expect(restored.workspace, DashboardWorkspace.thermals);
  });

  test('metric watch applies the matching alert setting', () {
    const settings = AppSettings();

    final updated = applyMetricAlertConfiguration(
      settings: settings,
      kind: MetricAlertKind.gpuTemperature,
      enabled: true,
      threshold: 79,
    );

    expect(updated.temperatureAlerts, isTrue);
    expect(updated.gpuTemperatureThreshold, 79);
    expect(updated.cpuTemperatureThreshold, settings.cpuTemperatureThreshold);
  });

  testWidgets('compact metric card fits a short dashboard slot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chartPreferences = ChartPreferences();
    final now = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 220,
              child: MetricCard(
                title: 'Memory',
                value: '40%',
                subtitle: 'System memory usage',
                icon: Icons.storage_rounded,
                accent: Colors.purple,
                graphPoints: [
                  TelemetrySample(
                    timestamp: now.subtract(const Duration(seconds: 1)),
                    value: 38,
                  ),
                  TelemetrySample(timestamp: now, value: 40),
                ],
                chartPreferences: chartPreferences,
                alertKind: MetricAlertKind.ramUsage,
                alertValue: 40,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });
}

void _noop() {}
