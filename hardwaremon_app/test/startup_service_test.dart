import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/services/startup_service.dart';

void main() {
  test('Linux startup entry is created, detected, and removed', () async {
    final temp = await Directory.systemTemp.createTemp(
      'hardwaremon-autostart-',
    );
    addTearDown(() => temp.delete(recursive: true));

    final service = StartupService(
      platform: StartupPlatform.linux,
      executablePath: '/usr/lib/hardwaremon/hardwaremon-bin',
      environment: {'XDG_CONFIG_HOME': '${temp.path}/config'},
    );

    final enabled = await service.setEnabled(true);
    expect(enabled.success, isTrue);

    final file = File('${temp.path}/config/autostart/hardwaremon.desktop');
    expect(await file.exists(), isTrue);
    final contents = await file.readAsString();
    expect(contents, contains('Exec="/usr/bin/hardwaremon" --startup'));
    expect(contents, contains('X-GNOME-Autostart-enabled=true'));

    expect((await service.detect()).enabled, isTrue);

    final disabled = await service.setEnabled(false);
    expect(disabled.success, isTrue);
    expect(await file.exists(), isFalse);
  });

  test('Flatpak startup entry launches the installed app id', () async {
    final temp = await Directory.systemTemp.createTemp(
      'hardwaremon-flatpak-autostart-',
    );
    addTearDown(() => temp.delete(recursive: true));

    final service = StartupService(
      platform: StartupPlatform.linux,
      executablePath: '/app/bin/hardwaremon',
      environment: {
        'XDG_CONFIG_HOME': '${temp.path}/config',
        'FLATPAK_ID': 'com.hardwaremon.HardwareMon',
      },
    );

    await service.setEnabled(true);
    final contents = await File(
      '${temp.path}/config/autostart/hardwaremon.desktop',
    ).readAsString();

    expect(
      contents,
      contains('Exec=flatpak run com.hardwaremon.HardwareMon --startup'),
    );
  });

  test('Windows startup uses the current-user Run key', () async {
    final calls = <List<String>>[];
    final service = StartupService(
      platform: StartupPlatform.windows,
      executablePath: r'C:\Program Files\HardwareMon\flutter_gui.exe',
      environment: const {},
      processRunner: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return ProcessResult(1, 0, '', '');
      },
    );

    final result = await service.setEnabled(true);

    expect(result.success, isTrue);
    expect(calls.single.first, 'reg');
    expect(calls.single, contains('REG_SZ'));
    expect(
      calls.single,
      contains(r'"C:\Program Files\HardwareMon\flutter_gui.exe" --startup'),
    );
  });
}
