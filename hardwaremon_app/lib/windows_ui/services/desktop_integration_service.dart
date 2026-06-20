import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/alert_service.dart';
import '../models/app_settings.dart';
import 'settings_service.dart';
import 'startup_service.dart';
import 'telemetry_service.dart';

enum DesktopCommand {
  showHardwareMon,
  telemetryStudio,
  checkForUpdates,
  settings,
}

enum DesktopWindowAction { keepDefault, hideToTray, exitApplication }

DesktopWindowAction actionForMinimize({
  required AppSettings settings,
  required bool trayAvailable,
}) {
  return settings.minimiseToTray && trayAvailable
      ? DesktopWindowAction.hideToTray
      : DesktopWindowAction.keepDefault;
}

DesktopWindowAction actionForClose({
  required AppSettings settings,
  required bool trayAvailable,
}) {
  return settings.closeToTray && trayAvailable
      ? DesktopWindowAction.hideToTray
      : DesktopWindowAction.exitApplication;
}

class DesktopIntegrationService extends ChangeNotifier
    with WindowListener, TrayListener {
  DesktopIntegrationService._();

  static final DesktopIntegrationService instance =
      DesktopIntegrationService._();

  static const _trayEducationKey = 'trayEducationShown';

  final StreamController<DesktopCommand> _commands =
      StreamController<DesktopCommand>.broadcast();

  AppSettings _settings = const AppSettings();
  StartupService _startupService = StartupService();
  StartupConfigurationStatus _startupStatus = const StartupConfigurationStatus(
    supported: false,
    enabled: false,
    description: 'Startup integration has not been checked yet.',
  );
  TelemetryService? _telemetry;
  Future<void> Function()? _onExit;
  Timer? _trayRefreshTimer;

  bool _initialized = false;
  bool _isQuitting = false;
  bool _trayAvailable = false;
  String? _trayError;

  Stream<DesktopCommand> get commands => _commands.stream;
  bool get trayAvailable => _trayAvailable;
  String? get trayError => _trayError;
  StartupConfigurationStatus get startupStatus => _startupStatus;

  Future<AppSettings> initialize({
    required AppSettings settings,
    required Future<void> Function() onExit,
    StartupService? startupService,
  }) async {
    if (_initialized) {
      return _settings;
    }

    _settings = settings;
    _onExit = onExit;
    _startupService = startupService ?? StartupService();

    _startupStatus = await _startupService.detect();
    if (_startupStatus.supported &&
        _settings.launchOnStartup != _startupStatus.enabled) {
      _settings = _settings.copyWith(launchOnStartup: _startupStatus.enabled);
      await SettingsService().saveSettings(_settings);
    }

    if (!Platform.isWindows && !Platform.isLinux) {
      _initialized = true;
      notifyListeners();
      return _settings;
    }

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    await _initializeTray();

    _initialized = true;
    notifyListeners();
    return _settings;
  }

  void attachTelemetry(TelemetryService telemetry) {
    if (identical(_telemetry, telemetry)) return;
    _telemetry?.removeListener(_scheduleTrayRefresh);
    _telemetry = telemetry;
    telemetry.addListener(_scheduleTrayRefresh);
    _scheduleTrayRefresh();
  }

  void detachTelemetry(TelemetryService telemetry) {
    if (!identical(_telemetry, telemetry)) return;
    telemetry.removeListener(_scheduleTrayRefresh);
    _telemetry = null;
  }

  void applySettings(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  Future<StartupConfigurationResult> setLaunchOnStartup(bool enabled) async {
    final result = await _startupService.setEnabled(enabled);
    _startupStatus = StartupConfigurationStatus(
      supported: result.supported,
      enabled: result.enabled,
      description: result.description,
    );
    notifyListeners();
    return result;
  }

  Future<void> restoreWindow() async {
    if (!Platform.isWindows && !Platform.isLinux) return;

    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.focus();
    } catch (error) {
      debugPrint('Failed to restore HardwareMon window: $error');
    }
  }

  Future<void> hideToTray() async {
    if (!_trayAvailable) return;

    try {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      await _showTrayEducationNotification();
    } catch (error) {
      debugPrint('Failed to hide HardwareMon to tray: $error');
    }
  }

  Future<void> exitHardwareMon() => _requestExit();

  Future<void> _initializeTray() async {
    if (!await _linuxTrayHostAvailable()) {
      _trayAvailable = false;
      _trayError =
          'GNOME is not exposing an AppIndicator host. Install or enable the '
          'AppIndicator/KStatusNotifierItem extension to use tray features.';
      debugPrint(_trayError);
      return;
    }

    trayManager.addListener(this);

    try {
      final iconPath = Platform.isWindows
          ? 'windows/runner/resources/app_icon.ico'
          : 'assets/hardwaremon.png';
      await trayManager.setIcon(iconPath);
      _trayAvailable = true;
      _trayError = null;
      await _refreshTray();
    } catch (error) {
      _trayAvailable = false;
      _trayError = Platform.isLinux
          ? 'The Linux system tray is unavailable. GNOME may require the '
                'AppIndicator extension. ($error)'
          : 'The system tray is unavailable: $error';
      debugPrint(_trayError);
      trayManager.removeListener(this);
    }
  }

  Future<bool> _linuxTrayHostAvailable() async {
    if (!Platform.isLinux) return true;

    final desktop = (Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
        .toUpperCase();
    if (!desktop.contains('GNOME')) return true;

    try {
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.freedesktop.DBus',
        '--object-path',
        '/org/freedesktop/DBus',
        '--method',
        'org.freedesktop.DBus.NameHasOwner',
        'org.kde.StatusNotifierWatcher',
      ]).timeout(const Duration(seconds: 2));

      if (result.exitCode != 0) return true;
      return result.stdout.toString().toLowerCase().contains('true');
    } catch (_) {
      // If the desktop cannot be queried, let the native plugin try its
      // generic status-icon fallback rather than disabling tray support.
      return true;
    }
  }

  void _scheduleTrayRefresh() {
    if (!_trayAvailable) return;
    if (_trayRefreshTimer?.isActive == true) return;

    _trayRefreshTimer = Timer(const Duration(milliseconds: 600), _refreshTray);
  }

  Future<void> _refreshTray() async {
    if (!_trayAvailable) return;

    final telemetry = _telemetry;
    final cpu = telemetry?.cpuUsage ?? 0;
    final ram = telemetry?.ramUsage ?? 0;
    final gpu = telemetry?.gpuUsage ?? 0;
    final tooltip = 'HardwareMon\nCPU: $cpu%\nRAM: $ram%\nGPU: $gpu%';

    try {
      if (Platform.isWindows) {
        await trayManager.setToolTip(tooltip);
      }

      final menu = Menu(
        items: [
          MenuItem(
            label: 'CPU $cpu%  •  RAM $ram%  •  GPU $gpu%',
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(key: 'show', label: 'Show HardwareMon'),
          MenuItem(key: 'studio', label: 'Telemetry Studio'),
          MenuItem(key: 'updates', label: 'Check for Updates'),
          MenuItem(key: 'settings', label: 'Settings'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Exit HardwareMon'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (error) {
      debugPrint('Failed to refresh tray content: $error');
    }
  }

  Future<void> _showTrayEducationNotification() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_trayEducationKey) ?? false) return;

    final shown = await AlertService.instance.showDesktopNotification(
      identifier: 'hardwaremon-tray-first-run',
      title: 'HardwareMon',
      body: 'HardwareMon is still running in your system tray.',
      onClick: restoreWindow,
    );
    if (shown) {
      await prefs.setBool(_trayEducationKey, true);
    }
  }

  Future<void> _requestExit() async {
    if (_isQuitting) return;
    _isQuitting = true;

    try {
      _trayRefreshTimer?.cancel();
      _telemetry?.removeListener(_scheduleTrayRefresh);
      _telemetry?.stop();
      await _onExit?.call();
      if (_trayAvailable) {
        await trayManager.destroy();
      }
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (error) {
      debugPrint('Failed to exit HardwareMon cleanly: $error');
      exit(0);
    }
  }

  @override
  void onWindowMinimize() {
    if (actionForMinimize(settings: _settings, trayAvailable: _trayAvailable) ==
        DesktopWindowAction.hideToTray) {
      unawaited(hideToTray());
    }
  }

  @override
  void onWindowClose() {
    if (_isQuitting) return;

    switch (actionForClose(
      settings: _settings,
      trayAvailable: _trayAvailable,
    )) {
      case DesktopWindowAction.hideToTray:
        unawaited(hideToTray());
        break;
      case DesktopWindowAction.exitApplication:
        unawaited(_requestExit());
        break;
      case DesktopWindowAction.keepDefault:
        break;
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(restoreWindow());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _emitCommand(DesktopCommand.showHardwareMon);
        break;
      case 'studio':
        _emitCommand(DesktopCommand.telemetryStudio);
        break;
      case 'updates':
        _emitCommand(DesktopCommand.checkForUpdates);
        break;
      case 'settings':
        _emitCommand(DesktopCommand.settings);
        break;
      case 'exit':
        unawaited(_requestExit());
        break;
    }
  }

  void _emitCommand(DesktopCommand command) {
    unawaited(_restoreAndEmit(command));
  }

  Future<void> _restoreAndEmit(DesktopCommand command) async {
    await restoreWindow();
    _commands.add(command);
  }
}
