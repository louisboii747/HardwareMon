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
  });
}