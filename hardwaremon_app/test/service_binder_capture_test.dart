import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/core/theme/app_colors.dart';
import 'package:flutter_gui/windows_ui/core/theme/app_theme.dart';
import 'package:flutter_gui/windows_ui/screens/shell_screen.dart';

Future<void> _capture(
  WidgetTester tester, {
  required Size size,
  required String fileName,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues(const {});
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(AppColors.workOrderBlue),
      themeMode: ThemeMode.light,
      home: const ShellScreen(),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('../../.impeccable/review/$fileName'),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('captures the service binder desktop shell', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _capture(
      tester,
      size: const Size(1440, 900),
      fileName: 'service-binder-desktop.png',
    );
  });

  testWidgets('captures the service binder compact shell', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _capture(
      tester,
      size: const Size(980, 720),
      fileName: 'service-binder-compact.png',
    );
  });
}
