import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';
import 'package:flutter_gui/windows_ui/models/optimization_models.dart';
import 'package:flutter_gui/windows_ui/models/storage_models.dart';
import 'package:flutter_gui/windows_ui/screens/pages/optimization_page.dart';
import 'package:flutter_gui/windows_ui/services/optimization_service.dart';
import 'package:flutter_gui/windows_ui/services/storage_service.dart';
import 'package:flutter_gui/windows_ui/services/telemetry_service.dart';

void main() {
  testWidgets('optimisation page renders the full premium layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final telemetry = TelemetryService()
      ..cpuUsage = 32
      ..ramUsage = 58
      ..cpuTemp = 64
      ..gpuTemp = 61
      ..ramTotal = 32;
    final preferences = ChartPreferences();
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: OptimizationPage(
            telemetry: telemetry,
            chartPreferences: preferences,
            onOpenProcesses: () {},
            onOpenStorage: () {},
            optimizationService: _FakeOptimizationService(),
            storageService: _FakeStorageService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Optimisation'), findsOneWidget);
    expect(find.text('Overall health'), findsOneWidget);
    expect(find.text('Startup applications'), findsOneWidget);
    expect(find.text('Storage analysis'), findsOneWidget);
    expect(find.text('Memory insights'), findsOneWidget);
    expect(find.text('Thermal insights'), findsOneWidget);
    expect(find.text('Gaming Mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeOptimizationService extends OptimizationService {
  @override
  Future<OptimizationSnapshot> fetchSnapshot() async {
    return const OptimizationSnapshot(
      platform: 'Windows',
      startupScore: 84,
      startupApps: [
        StartupApplication(
          id: 'one',
          name: 'Example Sync',
          publisher: 'Example',
          command: 'example.exe',
          impact: 'medium',
          enabled: true,
          canToggle: true,
          detail: 'Managed for the current user.',
        ),
      ],
      temporaryBytes: 512 * 1024 * 1024,
      temporaryFileCount: 100,
      temporaryEstimateTruncated: false,
      temporaryLocations: [
        TemporaryFileLocation(
          label: 'Temporary files',
          path: r'C:\Temp',
          sizeBytes: 512 * 1024 * 1024,
          fileCount: 100,
        ),
      ],
      startupToggleSupported: true,
      gamingModeSupported: false,
      cleanupSupported: false,
    );
  }
}

class _FakeStorageService extends StorageService {
  @override
  Future<StorageSnapshot> fetchSnapshot() async {
    return StorageSnapshot(
      sampledAt: DateTime(2026, 6, 21),
      totalCapacity: 1024 * 1024 * 1024 * 1000,
      usedCapacity: 1024 * 1024 * 1024 * 600,
      freeCapacity: 1024 * 1024 * 1024 * 400,
      usedPercent: 60,
      readBps: 0,
      writeBps: 0,
      peakReadBps: 0,
      peakWriteBps: 0,
      temperatureC: 40,
      health: StorageHealth.healthy,
      storageScore: 90,
      insights: const [],
      drives: const [],
    );
  }

  @override
  Future<StorageHistory> fetchHistory({
    String? driveId,
    int rangeSeconds = 3600,
    int points = 360,
  }) async {
    return const StorageHistory(samples: [], heatmap: [], forecast: null);
  }
}
