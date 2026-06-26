import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/screens/pages/reliability_page.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

void main() {
  testWidgets('reliability page renders incident timeline and runbook', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final telemetry = TelemetryService()
      ..cpuUsage = 82
      ..ramUsage = 68
      ..gpuUsage = 44
      ..diskUsage = 72
      ..cpuTemp = 81
      ..gpuTemp = 66
      ..lastUpdated = now
      ..sessionStatisticsStartedAt = now.subtract(const Duration(minutes: 18));

    telemetry.cpuHistory.addAll(_samples([48, 55, 63, 76, 82], now));
    telemetry.ramHistory.addAll(_samples([50, 58, 62, 65, 68], now));
    telemetry.gpuUsageHistory.addAll(_samples([22, 28, 36, 40, 44], now));
    telemetry.cpuTempHistory.addAll(_samples([58, 64, 72, 78, 81], now));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ReliabilityPage(
            telemetry: telemetry,
            onOpenPerformance: () {},
            onOpenProcesses: () {},
            onOpenStorage: () {},
            onOpenNetwork: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reliability'), findsOneWidget);
    expect(find.text('Live Incident Timeline'), findsOneWidget);
    expect(find.text('Session Drift'), findsOneWidget);
    expect(find.text('Recommended Next Actions'), findsOneWidget);
    expect(find.text('Inspect top workloads'), findsOneWidget);
    expect(find.text('Review thermals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<TelemetrySample> _samples(List<double> values, DateTime now) {
  return [
    for (var index = 0; index < values.length; index++)
      TelemetrySample(
        timestamp: now.subtract(Duration(seconds: values.length - index)),
        value: values[index],
      ),
  ];
}
