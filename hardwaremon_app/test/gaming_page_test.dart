import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/gaming_models.dart';
import 'package:flutter_gui/windows_ui/models/card_workspace.dart';
import 'package:flutter_gui/windows_ui/screens/pages/gaming_page.dart';
import 'package:flutter_gui/windows_ui/services/gaming_service.dart';

void main() {
  test('gaming models tolerate missing backend fields', () {
    final current = GamingCurrent.fromJson(const {});
    final session = GamingSession.fromJson(const {});
    final stats = GamingStatistics.fromJson(const {});

    expect(current.active, isFalse);
    expect(current.session, isNull);
    expect(session.gameName, 'Unknown game');
    expect(session.totalSamples, 0);
    expect(stats.totalSessions, 0);
  });

  testWidgets('gaming page renders idle detector state', (tester) async {
    tester.view.physicalSize = const Size(720, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GamingPage(
            service: _IdleGamingService(),
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gaming'), findsOneWidget);
    expect(find.text('Waiting for a known game'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gaming page renders an active session', (tester) async {
    tester.view.physicalSize = const Size(900, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GamingPage(
            service: _ActiveGamingService(),
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE SESSION'), findsOneWidget);
    expect(find.text('Test Game'), findsOneWidget);
    expect(find.text('CPU'), findsWidgets);
    expect(find.text('GPU'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gaming page can switch to history and statistics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(940, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GamingPage(
            service: _HistoryGamingService(),
            cardWorkspacePreferences: CardWorkspacePreferences(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Game'), findsOneWidget);
    expect(find.text('Peak GPU'), findsWidgets);

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Most Played'), findsOneWidget);
    expect(find.text('Total Hours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _IdleGamingService extends GamingService {
  @override
  Future<GamingCurrent> fetchCurrent() async => const GamingCurrent(
    active: false,
    session: null,
    lastEvent: null,
    knownGames: 12,
    pollIntervalSeconds: 5,
  );

  @override
  Future<List<GamingSession>> fetchHistory({int limit = 50}) async => const [];

  @override
  Future<GamingStatistics> fetchStatistics() async => _statistics();

  @override
  Future<GamingSession?> fetchLatest() async => null;
}

class _ActiveGamingService extends _IdleGamingService {
  final GamingSession _session = _sessionFromJson(
    id: 'active',
    name: 'Test Game',
    status: 'active',
    endedAt: null,
  );

  @override
  Future<GamingCurrent> fetchCurrent() async => GamingCurrent(
    active: true,
    session: _session,
    lastEvent: null,
    knownGames: 12,
    pollIntervalSeconds: 5,
  );
}

class _HistoryGamingService extends _IdleGamingService {
  final GamingSession _session = _sessionFromJson(
    id: 'completed',
    name: 'Completed Game',
    status: 'completed',
    endedAt: '2026-07-11T19:30:00Z',
  );

  @override
  Future<List<GamingSession>> fetchHistory({int limit = 50}) async => [
    _session,
  ];

  @override
  Future<GamingStatistics> fetchStatistics() async =>
      _statistics(session: _session);

  @override
  Future<GamingSession?> fetchLatest() async => _session;
}

GamingStatistics _statistics({GamingSession? session}) {
  return GamingStatistics(
    totalSessions: session == null ? 0 : 1,
    totalGamingSeconds: session?.durationSeconds ?? 0,
    totalGamingHours: session == null ? 0 : 1.2,
    averageSessionSeconds: session?.durationSeconds ?? 0,
    mostPlayedGame: session == null
        ? null
        : const GamingGameAggregate(
            gameName: 'Completed Game',
            sessions: 1,
            durationSeconds: 4200,
          ),
    longestSession: session,
    hottestRecordedSession: session,
    averageCpuTemperature: session?.avgCpuTemperature,
    averageGpuTemperature: session?.avgGpuTemperature,
    gamesPlayed: session == null ? 0 : 1,
    largestGpuUsage: session?.maxGpuUsage,
    largestCpuUsage: session?.maxCpuUsage,
    knownGames: 12,
  );
}

GamingSession _sessionFromJson({
  required String id,
  required String name,
  required String status,
  required String? endedAt,
}) {
  return GamingSession.fromJson({
    'id': id,
    'game_name': name,
    'executable': 'testgame.exe',
    'started_at': '2026-07-11T18:20:00Z',
    'ended_at': endedAt,
    'duration_seconds': 4200.0,
    'platform': 'Windows',
    'avg_cpu_usage': 44.0,
    'avg_gpu_usage': 72.0,
    'avg_ram_usage': 61.0,
    'avg_cpu_temperature': 66.0,
    'avg_gpu_temperature': 70.0,
    'peak_cpu_temperature': 82.0,
    'peak_gpu_temperature': 78.0,
    'peak_ram_usage': 73.0,
    'peak_gpu_usage': 91.0,
    'avg_cpu_clock': 4300.0,
    'avg_gpu_power': 181.0,
    'avg_cpu_power': 74.0,
    'max_cpu_usage': 88.0,
    'max_gpu_usage': 91.0,
    'total_samples': 14,
    'hardwaremon_version': 'test',
    'status': status,
    'game': const {
      'name': 'Test Game',
      'executables': ['testgame.exe'],
      'genre': 'Action',
      'publisher': 'HardwareMon',
    },
    'active_processes': const [
      {'game_name': 'Test Game', 'executable': 'testgame.exe', 'pid': 123},
    ],
    'latest_sample': const {
      'sampled_at': '2026-07-11T18:21:00Z',
      'cpu_usage': 48.0,
      'gpu_usage': 80.0,
      'ram_usage': 64.0,
      'cpu_temperature': 68.0,
      'gpu_temperature': 72.0,
      'cpu_clock': 4300.0,
      'gpu_power': 190.0,
      'cpu_power': 78.0,
    },
  });
}
