import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/telemetry_insights.dart';
import 'package:flutter_gui/windows_ui/widgets/system_intelligence_hero.dart';

void main() {
  const profile = SystemHealthProfile(
    overallScore: 86,
    stateLabel: 'Healthy',
    observation:
        'The system is balancing the current workload without a critical resource constraint.',
    bottleneck: 'No active bottleneck',
    signals: [
      SystemHealthSignal(
        dimension: SystemHealthDimension.performance,
        score: 88,
        label: 'Performance',
        detail: 'Responsive headroom',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.memory,
        score: 74,
        label: 'Memory',
        detail: '38% headroom',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.thermal,
        score: 92,
        label: 'Thermals',
        detail: '61°C peak now',
      ),
      SystemHealthSignal(
        dimension: SystemHealthDimension.efficiency,
        score: 83,
        label: 'Efficiency',
        detail: '74 W package draw',
      ),
    ],
  );

  testWidgets('system intelligence hero adapts to a compact desktop width', (
    tester,
  ) async {
    var performanceOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: SystemIntelligenceHero(
                profile: profile,
                onOpenPerformance: () => performanceOpened = true,
                onOpenProcesses: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SYSTEM INTELLIGENCE'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Thermals'), findsOneWidget);

    await tester.tap(find.text('Explore session'));
    expect(performanceOpened, isTrue);
  });
}
