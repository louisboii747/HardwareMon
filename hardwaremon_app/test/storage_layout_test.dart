import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/storage_models.dart';
import 'package:flutter_gui/windows_ui/screens/pages/storage_page.dart';
import 'package:flutter_gui/windows_ui/widgets/storage_visuals.dart';

const _longDrive = StorageDrive(
  id: 'very-long-drive-identifier',
  mountPoint: '/media/a-very-long-mounted-volume-name',
  label: 'A Very Long Production Archive Drive Name',
  filesystem: 'btrfs-with-a-long-description',
  device: '/dev/mapper/a-very-long-encrypted-device-name',
  model: 'Example Corporation Extremely Long Enterprise Storage Model',
  serial: 'SERIAL-NUMBER-WITH-MANY-CHARACTERS',
  interfaceType: 'Thunderbolt NVMe enclosure',
  totalBytes: 4000000000000,
  usedBytes: 3800000000000,
  freeBytes: 200000000000,
  usedPercent: 95,
  readBps: 734003200,
  writeBps: 419430400,
  temperatureC: 67,
  health: StorageHealth.critical,
  smartStatus: 'Critical warning reported by SMART',
  removable: false,
  score: 18,
  insights: [
    StorageInsight(
      severity: StorageHealth.critical,
      title: 'Drive nearly full and temperature elevated',
      message:
          'This deliberately long health explanation verifies that expanded content wraps without overflowing.',
    ),
  ],
);

void main() {
  testWidgets('drive card expands safely at narrow desktop widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: StorageDriveCard(
              drive: _longDrive,
              onOpen: () => opened = true,
              onOpenPath: () async {},
              onCopy: () async {},
              onRefresh: () async {},
              onScan: () {},
              onBenchmark: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Expand drive card'));
    await tester.pumpAndSettle();

    expect(find.text(_longDrive.model), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(_longDrive.model));
    await tester.pump();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage fleet remains overflow-free when narrow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: StorageFleetView(
              drives: const [_longDrive],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text(_longDrive.displayName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
