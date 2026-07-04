import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/customization_preferences.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';
import 'package:flutter_gui/windows_ui/widgets/dashboard_companion_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enabled companion summaries render at compact widths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'customizationEnabledWidgets':
          'hardwareHealth,activityFeed,benchmarks,updates',
    });
    final preferences = CustomizationPreferences();
    await preferences.load();
    addTearDown(preferences.dispose);
    final telemetry = TelemetryService()
      ..cpuUsage = 34
      ..ramUsage = 58
      ..diskUsage = 42
      ..lastUpdated = DateTime.now();

    tester.view.physicalSize = const Size(620, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardCompanionWidgets(
              telemetry: telemetry,
              preferences: preferences,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Hardware Health'), findsOneWidget);
    expect(find.text('Activity Feed'), findsOneWidget);
    expect(find.text('Benchmarks'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
