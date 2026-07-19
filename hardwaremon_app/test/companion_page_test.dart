import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/screens/pages/companion_page.dart';
import 'package:flutter_gui/windows_ui/services/companion_service.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';
import 'package:flutter_gui/windows_ui/models/card_workspace.dart';

void main() {
  testWidgets('companion centre exposes private sharing and export controls', (
    tester,
  ) async {
    final service = CompanionService(snapshotProvider: () => const {});
    service.portableMode = const PortableModeInfo(
      active: false,
      dataDirectory: 'test',
      reason: 'Installed data directories are in use',
    );
    service.inventory = {
      'cpu': {'name': 'Test CPU'},
      'operating_system': {'name': 'Windows'},
      'storage': <Object>[],
      'network_adapters': <Object>[],
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CompanionPage(
            telemetry: TelemetryService(),
            service: service,
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Companion Centre'), findsOneWidget);
    expect(find.text('Shareable system snapshot'), findsOneWidget);
    expect(find.text('Local Web Dashboard'), findsOneWidget);
    expect(find.text('Start & pair'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hardware Inventory'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hardware Inventory'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Export Centre'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Export Centre'), findsOneWidget);
  });
}
