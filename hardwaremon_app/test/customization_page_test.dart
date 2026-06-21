import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';
import 'package:flutter_gui/windows_ui/models/customization_preferences.dart';
import 'package:flutter_gui/windows_ui/models/dashboard_preferences.dart';
import 'package:flutter_gui/windows_ui/screens/pages/customization_page.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customization studio renders editors and live preview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final charts = ChartPreferences();
    final dashboard = DashboardPreferences();
    final studio = CustomizationPreferences();
    await charts.load();
    await dashboard.load();
    await studio.load();
    addTearDown(charts.dispose);
    addTearDown(dashboard.dispose);
    addTearDown(studio.dispose);

    final telemetry = TelemetryService()
      ..cpuUsage = 42
      ..ramUsage = 61;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: CustomizationPage(
              telemetry: telemetry,
              chartPreferences: charts,
              dashboardPreferences: dashboard,
              customizationPreferences: studio,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customization'), findsOneWidget);
    expect(find.text('LIVE PREVIEW'), findsOneWidget);
    expect(find.text('Dashboard Layout Editor'), findsOneWidget);
    expect(find.text('Theme Studio'), findsOneWidget);
    expect(find.text('Sidebar Customization'), findsOneWidget);
    expect(find.text('Graph Customization'), findsOneWidget);
    expect(find.text('Animation Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
