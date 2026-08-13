import 'dart:io';

class LogService {
  static Future<void> openLogsFolder() async {
    final logsPath = await getLogsDirectory();

    final dir = Directory(logsPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    if (Platform.isWindows) {
      await Process.run('explorer.exe', [logsPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [logsPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [logsPath]);
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  static Future<String> getLogsDirectory() async {
    return logsDirectoryFor(
      operatingSystem: Platform.operatingSystem,
      environment: Platform.environment,
    );
  }

  static String logsDirectoryFor({
    required String operatingSystem,
    required Map<String, String> environment,
  }) {
    switch (operatingSystem.toLowerCase()) {
      case 'windows':
        final appData = _requiredDirectory(
          environment,
          'LOCALAPPDATA',
          operatingSystem,
        );
        return '$appData\\HardwareMon\\logs';
      case 'linux':
        final home = _requiredDirectory(environment, 'HOME', operatingSystem);
        return '$home/.local/share/hardwaremon/logs';
      case 'macos':
        final home = _requiredDirectory(environment, 'HOME', operatingSystem);
        return '$home/Library/Logs/HardwareMon';
      default:
        throw UnsupportedError('Platform not supported: $operatingSystem');
    }
  }

  static String _requiredDirectory(
    Map<String, String> environment,
    String key,
    String operatingSystem,
  ) {
    final value = environment[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError(
        '$key is unavailable; cannot resolve HardwareMon logs on '
        '$operatingSystem.',
      );
    }
    return value;
  }
}
