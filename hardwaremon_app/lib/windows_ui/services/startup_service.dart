import 'dart:io';

enum StartupPlatform { windows, linux, unsupported }

typedef StartupProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class StartupConfigurationStatus {
  final bool supported;
  final bool enabled;
  final String description;

  const StartupConfigurationStatus({
    required this.supported,
    required this.enabled,
    required this.description,
  });
}

class StartupConfigurationResult extends StartupConfigurationStatus {
  final bool success;

  const StartupConfigurationResult({
    required super.supported,
    required super.enabled,
    required super.description,
    required this.success,
  });
}

class StartupService {
  static const _windowsRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _windowsValueName = 'HardwareMon';
  static const _linuxFileName = 'hardwaremon.desktop';

  final StartupPlatform platform;
  final String executablePath;
  final Map<String, String> environment;
  final StartupProcessRunner processRunner;

  StartupService({
    StartupPlatform? platform,
    String? executablePath,
    Map<String, String>? environment,
    StartupProcessRunner? processRunner,
  }) : platform = platform ?? _currentPlatform(),
       executablePath = executablePath ?? Platform.resolvedExecutable,
       environment = environment ?? Platform.environment,
       processRunner = processRunner ?? Process.run;

  static StartupPlatform _currentPlatform() {
    if (Platform.isWindows) return StartupPlatform.windows;
    if (Platform.isLinux) return StartupPlatform.linux;
    return StartupPlatform.unsupported;
  }

  Future<StartupConfigurationStatus> detect() async {
    try {
      return switch (platform) {
        StartupPlatform.windows => _detectWindows(),
        StartupPlatform.linux => _detectLinux(),
        StartupPlatform.unsupported => Future.value(
          const StartupConfigurationStatus(
            supported: false,
            enabled: false,
            description: 'Launch on startup is supported on Windows and Linux.',
          ),
        ),
      };
    } catch (error) {
      return StartupConfigurationStatus(
        supported: false,
        enabled: false,
        description: 'Startup configuration is unavailable: $error',
      );
    }
  }

  Future<StartupConfigurationResult> setEnabled(bool enabled) async {
    try {
      return switch (platform) {
        StartupPlatform.windows => _setWindowsEnabled(enabled),
        StartupPlatform.linux => _setLinuxEnabled(enabled),
        StartupPlatform.unsupported => Future.value(
          const StartupConfigurationResult(
            supported: false,
            enabled: false,
            success: false,
            description: 'Launch on startup is supported on Windows and Linux.',
          ),
        ),
      };
    } catch (error) {
      return StartupConfigurationResult(
        supported: true,
        enabled: !enabled,
        success: false,
        description: 'Could not update startup configuration: $error',
      );
    }
  }

  Future<StartupConfigurationStatus> _detectWindows() async {
    final result = await processRunner('reg', [
      'query',
      _windowsRunKey,
      '/v',
      _windowsValueName,
    ]);
    final enabled = result.exitCode == 0;

    return StartupConfigurationStatus(
      supported: true,
      enabled: enabled,
      description: enabled
          ? 'Enabled through the current-user Windows Run key.'
          : 'Not registered in the current-user Windows Run key.',
    );
  }

  Future<StartupConfigurationResult> _setWindowsEnabled(bool enabled) async {
    if (!enabled) {
      final current = await _detectWindows();
      if (!current.enabled) {
        return const StartupConfigurationResult(
          supported: true,
          enabled: false,
          success: true,
          description: 'HardwareMon is not registered in Windows startup.',
        );
      }
    }

    final arguments = enabled
        ? [
            'add',
            _windowsRunKey,
            '/v',
            _windowsValueName,
            '/t',
            'REG_SZ',
            '/d',
            '"$executablePath" --startup',
            '/f',
          ]
        : ['delete', _windowsRunKey, '/v', _windowsValueName, '/f'];
    final result = await processRunner('reg', arguments);
    final success =
        result.exitCode == 0 ||
        (!enabled &&
            result.stderr.toString().toLowerCase().contains('unable to find'));

    return StartupConfigurationResult(
      supported: true,
      enabled: success ? enabled : !enabled,
      success: success,
      description: success
          ? enabled
                ? 'HardwareMon will launch when you sign in to Windows.'
                : 'HardwareMon was removed from Windows startup.'
          : 'Windows rejected the startup configuration change.',
    );
  }

  Future<StartupConfigurationStatus> _detectLinux() async {
    final file = File(_linuxAutostartPath);
    final enabled = await file.exists();

    return StartupConfigurationStatus(
      supported: true,
      enabled: enabled,
      description: enabled
          ? 'Enabled through ~/.config/autostart/$_linuxFileName.'
          : 'No HardwareMon XDG autostart entry was found.',
    );
  }

  Future<StartupConfigurationResult> _setLinuxEnabled(bool enabled) async {
    final file = File(_linuxAutostartPath);

    if (enabled) {
      await file.parent.create(recursive: true);
      await file.writeAsString(_linuxDesktopEntry, flush: true);
    } else if (await file.exists()) {
      await file.delete();
    }

    return StartupConfigurationResult(
      supported: true,
      enabled: enabled,
      success: true,
      description: enabled
          ? 'HardwareMon will launch when your Linux desktop session starts.'
          : 'HardwareMon was removed from Linux desktop autostart.',
    );
  }

  String get _linuxAutostartPath {
    final configHome = environment['XDG_CONFIG_HOME']?.trim();
    if (configHome != null && configHome.isNotEmpty) {
      return '$configHome/autostart/$_linuxFileName';
    }

    final home = environment['HOME']?.trim();
    if (home == null || home.isEmpty) {
      throw const FileSystemException(
        'HOME and XDG_CONFIG_HOME are unavailable',
      );
    }

    return '$home/.config/autostart/$_linuxFileName';
  }

  String get _linuxDesktopEntry {
    final flatpakId = environment['FLATPAK_ID']?.trim();
    final packagedCommand =
        executablePath.replaceAll(r'\', '/').contains('/usr/lib/hardwaremon/')
        ? '/usr/bin/hardwaremon'
        : executablePath;
    final command = flatpakId != null && flatpakId.isNotEmpty
        ? 'flatpak run $flatpakId --startup'
        : '"${_escapeDesktopExec(packagedCommand)}" --startup';

    return '''
[Desktop Entry]
Type=Application
Version=1.0
Name=HardwareMon
Comment=Start HardwareMon system monitoring
Exec=$command
Icon=${flatpakId != null && flatpakId.isNotEmpty ? flatpakId : 'hardwaremon'}
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
Hidden=false
''';
  }

  String _escapeDesktopExec(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
