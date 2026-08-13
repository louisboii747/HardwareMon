import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/services/log_service.dart';

void main() {
  group('LogService.logsDirectoryFor', () {
    test('uses the user Library logs directory on macOS', () {
      expect(
        LogService.logsDirectoryFor(
          operatingSystem: 'macos',
          environment: const {'HOME': '/Users/hardwaremon'},
        ),
        '/Users/hardwaremon/Library/Logs/HardwareMon',
      );
    });

    test('keeps the existing Windows and Linux locations', () {
      expect(
        LogService.logsDirectoryFor(
          operatingSystem: 'windows',
          environment: const {'LOCALAPPDATA': r'C:\Users\hm\AppData\Local'},
        ),
        r'C:\Users\hm\AppData\Local\HardwareMon\logs',
      );
      expect(
        LogService.logsDirectoryFor(
          operatingSystem: 'linux',
          environment: const {'HOME': '/home/hm'},
        ),
        '/home/hm/.local/share/hardwaremon/logs',
      );
    });

    test('fails clearly when the platform home is unavailable', () {
      expect(
        () => LogService.logsDirectoryFor(
          operatingSystem: 'macos',
          environment: const {},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
