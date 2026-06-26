import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/process_info.dart';
import 'package:flutter_gui/windows_ui/screens/pages/processes_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('processes page uses compact layout before rows overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(840, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final processes = [
      ProcessInfo(
        pid: 4242,
        name: 'VeryLongDeveloperToolProcessNameThatShouldNeverOverflow.exe',
        cpu: 84.6,
        ram: 1536,
        isSystem: false,
        username: 'local-user',
        status: 'running',
        memoryPercent: 12.4,
        threadCount: 28,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ProcessInfo(
        pid: 7,
        name: 'kernel_task',
        cpu: 2.1,
        ram: 512,
        isSystem: true,
        status: 'sleeping',
        memoryPercent: 4.1,
        threadCount: 96,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: ProcessesPage(initialProcesses: processes, autoLoad: false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Compact rows'), findsOneWidget);
    expect(find.text('PID'), findsWidgets);
    final exception = tester.takeException();
    if (exception != null) {
      fail(exception is FlutterError ? exception.toStringDeep() : '$exception');
    }
  });
}
