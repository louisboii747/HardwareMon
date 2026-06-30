import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/benchmark_models.dart';
import 'package:flutter_gui/windows_ui/screens/pages/benchmark_page.dart';
import 'package:flutter_gui/windows_ui/services/benchmark_service.dart';
import 'package:flutter_gui/windows_ui/services/benchmark_privacy_preferences.dart';

void main() {
  test('benchmark models tolerate missing backend fields', () {
    final status = BenchmarkStatus.fromJson(const {});
    final result = BenchmarkResult.fromJson(const {});

    expect(status.state, BenchmarkRunState.idle);
    expect(status.progress, 0);
    expect(result.overallScore, 0);
    expect(result.rawResult, isEmpty);
  });

  testWidgets('benchmark page is responsive with no previous results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: BenchmarkPage(service: _EmptyBenchmarkService())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('Start Benchmark'), findsOneWidget);
    expect(find.text('Your first result will appear here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed backend responses show a recoverable error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BenchmarkPage(service: _FailingBenchmarkService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed results render offline rankings and filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BenchmarkPage(service: _HistoryBenchmarkService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overall Performance'), findsOneWidget);
    expect(find.text('Identical CPU'), findsOneWidget);
    expect(find.text('Comparison chart'), findsOneWidget);
    expect(find.text('Local history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly completed run asks before anonymous submission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BenchmarkPage(
            service: _CompletingBenchmarkService(),
            privacyPreferences: _AlwaysPromptPrivacyPreferences(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Help improve HardwareMon?'), findsOneWidget);
    expect(find.text('Keep local only'), findsOneWidget);
    expect(find.text('Submit anonymously'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyBenchmarkService extends BenchmarkService {
  @override
  Future<BenchmarkStatus> fetchStatus() async => const BenchmarkStatus.idle();

  @override
  Future<BenchmarkResult?> fetchLatest() async => null;

  @override
  Future<List<BenchmarkResult>> fetchResults({int limit = 20}) async =>
      const [];
}

class _FailingBenchmarkService extends BenchmarkService {
  @override
  Future<BenchmarkStatus> fetchStatus() {
    throw StateError('Benchmark Mode is temporarily unavailable.');
  }

  @override
  Future<BenchmarkResult?> fetchLatest() async => null;

  @override
  Future<List<BenchmarkResult>> fetchResults({int limit = 20}) async =>
      const [];
}

class _HistoryBenchmarkService extends BenchmarkService {
  late final List<BenchmarkResult> _results = [
    _result(2, 1200),
    _result(1, 1000),
  ];

  @override
  Future<BenchmarkStatus> fetchStatus() async => const BenchmarkStatus.idle();

  @override
  Future<BenchmarkResult?> fetchLatest() async => _results.first;

  @override
  Future<List<BenchmarkResult>> fetchResults({int limit = 20}) async =>
      _results;
}

class _CompletingBenchmarkService extends BenchmarkService {
  int _statusRequests = 0;
  final BenchmarkResult _completed = _result(1, 1100);

  @override
  Future<BenchmarkStatus> fetchStatus() async {
    _statusRequests += 1;
    if (_statusRequests == 1) {
      return const BenchmarkStatus(
        state: BenchmarkRunState.running,
        runId: 'test-run',
        currentTest: 'Disk read',
        progress: 95,
        elapsedTime: 4,
        errorMessage: null,
        resultId: null,
      );
    }
    return const BenchmarkStatus(
      state: BenchmarkRunState.completed,
      runId: 'test-run',
      currentTest: 'Benchmark complete',
      progress: 100,
      elapsedTime: 5,
      errorMessage: null,
      resultId: 1,
    );
  }

  @override
  Future<BenchmarkResult?> fetchLatest() async => _completed;

  @override
  Future<List<BenchmarkResult>> fetchResults({int limit = 20}) async => [
    _completed,
  ];
}

class _AlwaysPromptPrivacyPreferences extends BenchmarkPrivacyPreferences {
  @override
  Future<bool> shouldPromptForResult(int resultId) async => true;

  @override
  Future<void> markPrompted(int resultId) async {}
}

BenchmarkResult _result(int id, int score) {
  return BenchmarkResult.fromJson({
    'id': id,
    'timestamp': '2026-06-30T12:00:00Z',
    'device_name': 'Test device',
    'platform': 'Windows',
    'operating_system': 'Windows',
    'cpu_model': 'Test CPU',
    'cpu_cores': 8,
    'cpu_threads': 16,
    'gpu_model': 'Test GPU',
    'ram_total': 16 * 1024 * 1024 * 1024,
    'ram_speed_mhz': 3200,
    'storage_type': 'NVMe',
    'benchmark_version': '1.0',
    'overall_score': score,
    'cpu_score': score,
    'memory_score': score - 20,
    'disk_score': score + 20,
    'duration': 5.0,
    'raw_result': const {},
  });
}
