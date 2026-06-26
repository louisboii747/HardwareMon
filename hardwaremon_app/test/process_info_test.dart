import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/process_info.dart';

void main() {
  test('process info decodes optional portable metadata', () {
    final process = ProcessInfo.fromJson({
      'pid': 42,
      'name': 'example',
      'cpu': 12.5,
      'ram': 640,
      'is_system': false,
      'username': 'louis',
      'status': 'running',
      'memory_percent': 1.25,
      'thread_count': 8,
      'started_at': 1710000000,
    });

    expect(process.pid, 42);
    expect(process.cpu, 12.5);
    expect(process.ram, 640);
    expect(process.username, 'louis');
    expect(process.status, 'running');
    expect(process.memoryPercent, 1.25);
    expect(process.threadCount, 8);
    expect(process.startedAt, isNotNull);
  });

  test('process info tolerates missing optional metadata', () {
    final process = ProcessInfo.fromJson({
      'pid': 7,
      'name': 'minimal',
      'cpu': 0,
      'ram': 0,
    });

    expect(process.isSystem, isFalse);
    expect(process.memoryPercent, 0);
    expect(process.username, isNull);
    expect(process.startedAt, isNull);
  });
}
