import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/app_settings.dart';
import 'package:flutter_gui/windows_ui/services/desktop_integration_service.dart';

void main() {
  test('minimise hides only when the setting and tray are available', () {
    expect(
      actionForMinimize(
        settings: const AppSettings(minimiseToTray: true),
        trayAvailable: true,
      ),
      DesktopWindowAction.hideToTray,
    );
    expect(
      actionForMinimize(
        settings: const AppSettings(minimiseToTray: true),
        trayAvailable: false,
      ),
      DesktopWindowAction.keepDefault,
    );
  });

  test('close exits when tray support is unavailable', () {
    expect(
      actionForClose(
        settings: const AppSettings(closeToTray: true),
        trayAvailable: true,
      ),
      DesktopWindowAction.hideToTray,
    );
    expect(
      actionForClose(
        settings: const AppSettings(closeToTray: true),
        trayAvailable: false,
      ),
      DesktopWindowAction.exitApplication,
    );
    expect(
      actionForClose(
        settings: const AppSettings(closeToTray: false),
        trayAvailable: true,
      ),
      DesktopWindowAction.exitApplication,
    );
  });
}
