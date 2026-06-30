import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/benchmark_comparison.dart';
import 'package:flutter_gui/windows_ui/models/benchmark_models.dart';
import 'package:flutter_gui/windows_ui/services/benchmark_comparison_provider.dart';

void main() {
  test(
    'local provider calculates version-compatible ranking statistics',
    () async {
      final target = _result(id: 2, overall: 1000);
      final provider = LocalBenchmarkComparisonProvider();
      final comparison = await provider.compare(
        result: target,
        results: [
          _result(id: 1, overall: 800),
          target,
          _result(id: 3, overall: 1200),
          _result(id: 4, overall: 9000, version: '2.0'),
        ],
        filter: BenchmarkComparisonFilter.identicalCpu,
      );

      expect(comparison.available, isTrue);
      expect(comparison.sampleSize, 3);
      expect(comparison.percentile, closeTo(33.33, 0.1));
      expect(comparison.averageScore, 1000);
      expect(comparison.medianScore, 1000);
      expect(comparison.lowestScore, 800);
      expect(comparison.topTenScore, 1200);
      expect(comparison.highestScore, 1200);
    },
  );

  test('filters match CPU GPU family and platform independently', () async {
    final target = _result(id: 1, overall: 1000);
    final results = [
      target,
      _result(id: 2, overall: 1100, gpu: 'Test GPU'),
      _result(id: 3, overall: 900, cpu: 'AMD Ryzen 7 7700X', gpu: 'Other GPU'),
      _result(id: 4, overall: 700, cpu: 'Intel Core i7-14700K', os: 'Linux'),
    ];
    final provider = LocalBenchmarkComparisonProvider();

    final cpuGpu = await provider.compare(
      result: target,
      results: results,
      filter: BenchmarkComparisonFilter.identicalCpuAndGpu,
    );
    final family = await provider.compare(
      result: target,
      results: results,
      filter: BenchmarkComparisonFilter.cpuFamily,
    );
    final platform = await provider.compare(
      result: target,
      results: results,
      filter: BenchmarkComparisonFilter.platform,
    );

    expect(cpuGpu.sampleSize, 2);
    expect(family.sampleSize, 3);
    expect(platform.sampleSize, 3);
  });

  test('anonymous payload excludes local and identifying fields', () {
    final result = _result(id: 9, overall: 1234);
    final payload = result.toAnonymousSubmissionJson();
    final encoded = jsonEncode(payload).toLowerCase();

    expect(payload['hardware'], isA<Map<String, dynamic>>());
    expect(encoded, isNot(contains('device_name')));
    expect(encoded, isNot(contains('test workstation')));
    expect(encoded, isNot(contains('serial')));
    expect(encoded, isNot(contains('ip_address')));
    expect(encoded, isNot(contains('raw_result')));
  });

  test(
    'remote placeholder performs no upload and coordinator falls back',
    () async {
      final result = _result(id: 1, overall: 1000);
      const remote = PlaceholderRemoteBenchmarkComparisonProvider();
      final coordinator = BenchmarkComparisonCoordinator(remote: remote);

      final comparison = await coordinator.compare(
        result: result,
        results: [result],
        filter: BenchmarkComparisonFilter.allResults,
      );
      final submission = await coordinator.submitAnonymously(result);

      expect(remote.isAvailable, isFalse);
      expect(comparison.available, isTrue);
      expect(comparison.offlineFallback, isTrue);
      expect(submission.status, BenchmarkSubmissionStatus.unavailable);
    },
  );
}

BenchmarkResult _result({
  required int id,
  required int overall,
  String version = '1.0',
  String cpu = 'AMD Ryzen 7 7800X3D',
  String? gpu = 'Test GPU',
  String os = 'Windows',
}) {
  return BenchmarkResult.fromJson({
    'id': id,
    'timestamp': '2026-06-30T12:00:00Z',
    'device_name': 'Test Workstation',
    'platform': '$os test build',
    'cpu_model': cpu,
    'cpu_cores': 8,
    'cpu_threads': 16,
    'gpu_model': gpu,
    'ram_total': 32 * 1024 * 1024 * 1024,
    'ram_speed_mhz': 6000,
    'storage_type': 'NVMe',
    'operating_system': os,
    'benchmark_version': version,
    'overall_score': overall,
    'cpu_score': overall,
    'memory_score': overall,
    'disk_score': overall,
    'duration': 5.2,
    'raw_result': const {},
  });
}
