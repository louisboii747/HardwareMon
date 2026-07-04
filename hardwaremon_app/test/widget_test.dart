// Basic smoke test – just checks the app renders without crashing.
// The backend is not running during tests, so data cards will show
// the "Connecting…" skeleton state, which is the correct behaviour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HardwareMonApp());

    // The shell should always be present regardless of backend state.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Sidebar icon is always rendered.
    expect(find.byIcon(Icons.memory_rounded), findsWidgets);

    // Allow entrance animations to finish, then dispose the shell cleanly so
    // animation and telemetry timers are cancelled before test teardown.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('rapid page revisits do not duplicate transition keys', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HardwareMonApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.bySemanticsLabel('Customization'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.bySemanticsLabel('Customization'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Customization'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });
}
