import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_gui/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build channels distinguish stable, development, and debug builds', () {
    expect(
      UpdateService.detectBuildChannel(version: '18.2.4', isDebug: false),
      UpdateBuildChannel.stable,
    );
    expect(
      UpdateService.detectBuildChannel(version: '18.3.0-dev', isDebug: false),
      UpdateBuildChannel.development,
    );
    expect(
      UpdateService.detectBuildChannel(version: '18.2.4', isDebug: true),
      UpdateBuildChannel.localDebug,
    );
  });

  test('semantic comparison does not offer downgrades', () {
    expect(UpdateService.compareVersions('18.2.3', '18.2.4'), lessThan(0));
    expect(UpdateService.compareVersions('18.2.4', '18.2.4'), 0);
    expect(UpdateService.compareVersions('18.3.0', '18.2.4'), greaterThan(0));
  });

  test('asset matching never crosses package types', () {
    final assets = [
      _asset('HardwareMon-v18.2.4.exe'),
      _asset('hardwaremon.deb'),
      _asset('hardwaremon.rpm'),
    ];

    expect(
      UpdateService.matchingAssetFor(
        assets,
        UpdatePackageType.windowsInstaller,
      )?.name,
      endsWith('.exe'),
    );
    expect(
      UpdateService.matchingAssetFor(assets, UpdatePackageType.deb)?.name,
      endsWith('.deb'),
    );
    expect(
      UpdateService.matchingAssetFor(assets, UpdatePackageType.rpm)?.name,
      endsWith('.rpm'),
    );
    expect(
      UpdateService.matchingAssetFor(assets, UpdatePackageType.manual),
      isNull,
    );
  });

  test('stable Windows build finds its installer update', () async {
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.windows,
    );
    addTearDown(fixture.dispose);

    final state = await fixture.service.checkForUpdates();

    expect(state.channel, UpdateBuildChannel.stable);
    expect(state.packageType, UpdatePackageType.windowsInstaller);
    expect(state.updateAvailable, isTrue);
    expect(state.asset?.name, 'HardwareMon-v18.2.4.exe');
    expect(state.canInstallAutomatically, isTrue);
  });

  test(
    'development builds are not marked outdated by stable releases',
    () async {
      final fixture = await _fixture(
        version: '18.3.0-dev',
        platform: UpdatePlatform.windows,
      );
      addTearDown(fixture.dispose);

      final state = await fixture.service.checkForUpdates();

      expect(state.channel, UpdateBuildChannel.development);
      expect(state.updateAvailable, isFalse);
      expect(state.statusMessage, contains('do not automatically downgrade'));
    },
  );

  test('Linux DEB installation is detected with dpkg metadata', () async {
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.linux,
      processRunner: (executable, arguments) async {
        if (executable == 'dpkg-query') {
          return ProcessResult(1, 0, 'install ok installed\n18.2.3', '');
        }
        return ProcessResult(1, 1, '', 'not installed');
      },
    );
    addTearDown(fixture.dispose);

    final state = await fixture.service.checkForUpdates();

    expect(state.packageType, UpdatePackageType.deb);
    expect(state.asset?.name, 'hardwaremon.deb');
    expect(state.canInstallAutomatically, isTrue);
  });

  test('Linux RPM installation is detected after dpkg misses', () async {
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.linux,
      processRunner: (executable, arguments) async {
        if (executable == 'rpm') {
          return ProcessResult(1, 0, '18.2.3', '');
        }
        return ProcessResult(1, 1, '', 'not installed');
      },
    );
    addTearDown(fixture.dispose);

    final state = await fixture.service.checkForUpdates();

    expect(state.packageType, UpdatePackageType.rpm);
    expect(state.asset?.name, 'hardwaremon.rpm');
  });

  test('unknown Linux installs fall back to manual updates', () async {
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.linux,
      processRunner: (_, _) async => ProcessResult(1, 1, '', 'not installed'),
    );
    addTearDown(fixture.dispose);

    final state = await fixture.service.checkForUpdates();

    expect(state.packageType, UpdatePackageType.manual);
    expect(state.updateAvailable, isTrue);
    expect(state.asset, isNull);
    expect(state.canInstallAutomatically, isFalse);
  });

  test('download streams progress and verifies GitHub asset size', () async {
    final packageBytes = List<int>.generate(128 * 1024, (index) => index % 251);
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.windows,
      packageBytes: packageBytes,
    );
    addTearDown(fixture.dispose);

    await fixture.service.checkForUpdates();
    final file = await fixture.service.downloadUpdate();

    expect(await file.exists(), isTrue);
    expect(await file.length(), packageBytes.length);
    expect(fixture.service.state.stage, UpdateStage.verifying);
    expect(fixture.service.state.progress, 1);
    expect(fixture.service.state.downloadedFilePath, file.path);
  });

  test('Windows install launches only the verified installer helper', () async {
    final starts = <({String executable, List<String> arguments})>[];
    var closed = false;
    final fixture = await _fixture(
      version: '18.2.3',
      platform: UpdatePlatform.windows,
      processStarter: (executable, arguments, mode) async {
        starts.add((executable: executable, arguments: arguments));
      },
    );
    addTearDown(fixture.dispose);

    await fixture.service.checkForUpdates();
    await fixture.service.performUpdate(
      closeApplication: () async => closed = true,
    );

    expect(starts, hasLength(1));
    expect(starts.single.executable, 'powershell.exe');
    expect(starts.single.arguments, contains('-PackagePath'));
    expect(
      starts.single.arguments.any((value) => value.endsWith('.exe')),
      isTrue,
    );
    final helperPath =
        starts.single.arguments[starts.single.arguments.indexOf('-File') + 1];
    final helper = await File(helperPath).readAsString();
    expect(helper, contains('/VERYSILENT'));
    expect(helper, contains('-Verb RunAs'));
    expect(helper, contains('Set-Content -LiteralPath \$MarkerPath'));
    expect(fixture.service.state.stage, UpdateStage.restarting);
    expect(closed, isTrue);
  });

  test(
    'DEB install helper uses pkexec and restarts the package launcher',
    () async {
      final starts = <({String executable, List<String> arguments})>[];
      final fixture = await _fixture(
        version: '18.2.3',
        platform: UpdatePlatform.linux,
        processRunner: (executable, arguments) async {
          if (executable == 'dpkg-query') {
            return ProcessResult(1, 0, 'install ok installed\n18.2.3', '');
          }
          return ProcessResult(1, 1, '', 'not installed');
        },
        processStarter: (executable, arguments, mode) async {
          starts.add((executable: executable, arguments: arguments));
        },
      );
      addTearDown(fixture.dispose);

      await fixture.service.checkForUpdates();
      await fixture.service.performUpdate(closeApplication: () async {});

      expect(starts.single.executable, '/bin/sh');
      final helper = await File(starts.single.arguments.first).readAsString();
      expect(helper, contains('pkexec apt install -y'));
      expect(helper, contains('nohup /usr/bin/hardwaremon'));
      expect(starts.single.arguments.last, UpdatePackageType.deb.name);
    },
  );
}

UpdateAsset _asset(String name) {
  return UpdateAsset(
    name: name,
    downloadUrl: Uri.parse('https://example.test/$name'),
    size: 128 * 1024,
  );
}

Future<_UpdateFixture> _fixture({
  required String version,
  required UpdatePlatform platform,
  ProcessRunner? processRunner,
  ProcessStarter? processStarter,
  List<int>? packageBytes,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'hardwaremon-updater-test-',
  );
  final bytes =
      packageBytes ?? List<int>.generate(128 * 1024, (index) => index % 251);
  final releaseJson = {
    'tag_name': 'v18.2.4',
    'body': 'A polished test release.',
    'published_at': '2026-06-20T09:42:48Z',
    'html_url':
        'https://github.com/louisboii747/HardwareMon/releases/tag/v18.2.4',
    'assets': [
      {
        'name': 'HardwareMon-v18.2.4.exe',
        'browser_download_url': 'https://example.test/HardwareMon-v18.2.4.exe',
        'size': bytes.length,
      },
      {
        'name': 'hardwaremon.deb',
        'browser_download_url': 'https://example.test/hardwaremon.deb',
        'size': bytes.length,
      },
      {
        'name': 'hardwaremon.rpm',
        'browser_download_url': 'https://example.test/hardwaremon.rpm',
        'size': bytes.length,
      },
    ],
  };
  final client = MockClient((request) async {
    if (request.url.host == 'api.github.com') {
      return http.Response(
        jsonEncode(releaseJson),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    return http.Response.bytes(bytes, 200);
  });
  final service = UpdateService(
    client: client,
    packageInfoLoader: () async => PackageInfo(
      appName: 'HardwareMon',
      packageName: 'com.hardwaremon.HardwareMon',
      version: version,
      buildNumber: '1',
    ),
    runtime: UpdateRuntime(
      platform: platform,
      isDebug: false,
      environment: const {},
      executablePath: platform == UpdatePlatform.windows
          ? r'C:\Program Files\HardwareMon\flutter_gui.exe'
          : '/usr/lib/hardwaremon/hardwaremon-bin',
      processId: 42,
    ),
    processRunner:
        processRunner ??
        (_, _) async => ProcessResult(1, 1, '', 'not installed'),
    processStarter: processStarter,
    temporaryDirectoryLoader: () async => tempDirectory,
    logsDirectoryLoader: () async => tempDirectory.path,
  );
  return _UpdateFixture(service, tempDirectory);
}

class _UpdateFixture {
  final UpdateService service;
  final Directory directory;

  const _UpdateFixture(this.service, this.directory);

  Future<void> dispose() async {
    service.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
