import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';
import 'package:flutter_gui/windows_ui/models/card_workspace.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_capabilities.dart';
import 'package:flutter_gui/windows_ui/screens/pages/performance_page.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

void main() {
  testWidgets('performance page exposes Telemetry Studio and controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final telemetry = TelemetryService();
    final preferences = ChartPreferences();
    final now = DateTime.now();
    telemetry.historicalCpuHistory.addAll([
      TelemetrySample(
        timestamp: now.subtract(const Duration(minutes: 1)),
        value: 25,
      ),
      TelemetrySample(timestamp: now, value: 45),
    ]);
    telemetry.historicalRamHistory.addAll([
      TelemetrySample(
        timestamp: now.subtract(const Duration(minutes: 1)),
        value: 50,
      ),
      TelemetrySample(timestamp: now, value: 55),
    ]);
    telemetry.historicalGpuHistory.addAll([
      TelemetrySample(
        timestamp: now.subtract(const Duration(minutes: 1)),
        value: 15,
      ),
      TelemetrySample(timestamp: now, value: 35),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformancePage(
            telemetry: telemetry,
            chartPreferences: preferences,
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Telemetry Studio'), findsOneWidget);
    expect(find.text('Session intelligence'), findsOneWidget);
    expect(find.text('Headroom'), findsOneWidget);
    expect(find.text('Session age'), findsOneWidget);
    expect(find.text('Copy report'), findsOneWidget);
    expect(find.text('Live recommendations'), findsOneWidget);
    expect(find.text('Reset stats'), findsOneWidget);
    expect(find.text('Smooth curves'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('macOS performance view prioritises supported metrics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final telemetry = TelemetryService()
      ..cpuName = 'Apple M4'
      ..capabilities = TelemetryCapabilities.fallback(isMacOS: true)
      ..platformInfo = const TelemetryPlatformInfo(
        system: 'Darwin',
        name: 'macOS',
        version: '15.5',
        architecture: 'arm64',
        deviceName: 'MacBook Air',
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerformancePage(
            telemetry: telemetry,
            chartPreferences: ChartPreferences(),
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Apple M4 · arm64'), findsOneWidget);
    expect(
      find.textContaining('CPU and memory monitoring are active'),
      findsOneWidget,
    );
    expect(find.text('CPU Temperature'), findsNothing);
    expect(find.text('GPU Temperature'), findsNothing);
    expect(find.text('Telemetry Studio'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
