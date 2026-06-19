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
    }
  }

  static Future<String> getLogsDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['LOCALAPPDATA'];
      return '$appData\\HardwareMon\\logs';
    }

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return '$home/.local/share/hardwaremon/logs';
    }

    throw UnsupportedError('Platform not supported');
  }
}
