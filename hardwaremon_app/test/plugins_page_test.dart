import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/screens/pages/plugins_page.dart';
import 'package:flutter_gui/windows_ui/services/companion_service.dart';
import 'package:flutter_gui/windows_ui/models/card_workspace.dart';

void main() {
  testWidgets(
    'plugin studio renders broker health and permission entry point',
    (tester) async {
      final service = CompanionService(snapshotProvider: () => const {});
      service.knownPluginCapabilities = const [
        'telemetry.read',
        'network.listen',
      ];
      service.plugins = [
        PluginDescriptor.fromJson({
          'id': 'org.hardwaremon.prometheus',
          'name': 'Prometheus Exporter',
          'version': '1.0.0',
          'publisher': 'HardwareMon',
          'description': 'Local metrics exporter',
          'official': true,
          'enabled': false,
          'approved': false,
          'status': 'stopped',
          'capabilities': ['telemetry.read', 'network.listen'],
        }),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PluginsPage(
              service: service,
              cardWorkspacePreferences: CardWorkspacePreferences(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Plugin Studio'), findsOneWidget);
      expect(find.text('Trust is explicit'), findsOneWidget);
      expect(find.text('Prometheus Exporter'), findsOneWidget);
      expect(find.text('Review permissions'), findsOneWidget);
    },
  );
}
