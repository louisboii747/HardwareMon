import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

const _githubLatestReleaseUrl =
    'https://api.github.com/repos/louisboii747/HardwareMon/releases/latest';
const _compiledAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '',
);

enum UpdateBuildChannel { stable, development, localDebug }

enum UpdatePlatform { windows, linux, unsupported }

enum UpdatePackageType { windowsInstaller, deb, rpm, manual, unsupported }

enum UpdateStage {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  restarting,
  complete,
  failed,
}

extension UpdateBuildChannelLabel on UpdateBuildChannel {
  String get label => switch (this) {
    UpdateBuildChannel.stable => 'Stable',
    UpdateBuildChannel.development => 'Development',
    UpdateBuildChannel.localDebug => 'Development',
  };

  String get buildDescription => switch (this) {
    UpdateBuildChannel.stable => 'Stable release build',
    UpdateBuildChannel.development => 'Development release build',
    UpdateBuildChannel.localDebug => 'Local debug build',
  };
}

extension UpdatePackageTypeLabel on UpdatePackageType {
  String get label => switch (this) {
    UpdatePackageType.windowsInstaller => 'Windows installer',
    UpdatePackageType.deb => 'DEB / APT',
    UpdatePackageType.rpm => 'RPM / DNF',
    UpdatePackageType.manual => 'Manual installation',
    UpdatePackageType.unsupported => 'Unsupported platform',
  };
}

extension UpdatePlatformLabel on UpdatePlatform {
  String get label => switch (this) {
    UpdatePlatform.windows => 'Windows',
    UpdatePlatform.linux => 'Linux',
    UpdatePlatform.unsupported => 'Unsupported',
  };
}

extension UpdateStageLabel on UpdateStage {
  String get label => switch (this) {
    UpdateStage.idle => 'Ready',
    UpdateStage.checking => 'Checking for updates',
    UpdateStage.available => 'Update available',
    UpdateStage.downloading => 'Downloading update',
    UpdateStage.verifying => 'Verifying download',
    UpdateStage.installing => 'Installing update',
    UpdateStage.restarting => 'Restarting HardwareMon',
    UpdateStage.complete => 'Update complete',
    UpdateStage.failed => 'Update failed',
  };

  bool get isBusy => switch (this) {
    UpdateStage.checking ||
    UpdateStage.downloading ||
    UpdateStage.verifying ||
    UpdateStage.installing ||
    UpdateStage.restarting => true,
    _ => false,
  };
}

class UpdateAsset {
  final String name;
  final Uri downloadUrl;
  final int size;

  const UpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> json) {
    return UpdateAsset(
      name: json['name']?.toString() ?? '',
      downloadUrl: Uri.parse(json['browser_download_url']?.toString() ?? ''),
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class UpdateRelease {
  final String version;
  final String tag;
  final String notes;
  final DateTime? publishedAt;
  final Uri htmlUrl;
  final List<UpdateAsset> assets;

  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.notes,
    required this.publishedAt,
    required this.htmlUrl,
    required this.assets,
  });

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString() ?? '';
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    return UpdateRelease(
      version: normalizeVersion(tag),
      tag: tag,
      notes: json['body']?.toString().trim() ?? '',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      htmlUrl: Uri.parse(
        json['html_url']?.toString() ??
            'https://github.com/louisboii747/HardwareMon/releases',
      ),
      assets: rawAssets
          .whereType<Map<String, dynamic>>()
          .map(UpdateAsset.fromJson)
          .toList(growable: false),
    );
  }
}

class UpdateState {
  final String currentVersion;
  final String latestVersion;
  final UpdateBuildChannel channel;
  final UpdatePlatform platform;
  final UpdatePackageType packageType;
  final UpdateStage stage;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final bool updateAvailable;
  final String statusMessage;
  final String? errorMessage;
  final UpdateRelease? release;
  final UpdateAsset? asset;
  final String? downloadedFilePath;

  const UpdateState({
    this.currentVersion = 'Detecting…',
    this.latestVersion = 'Not checked',
    this.channel = UpdateBuildChannel.development,
    this.platform = UpdatePlatform.unsupported,
    this.packageType = UpdatePackageType.unsupported,
    this.stage = UpdateStage.idle,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.updateAvailable = false,
    this.statusMessage = 'Ready to check for updates.',
    this.errorMessage,
    this.release,
    this.asset,
    this.downloadedFilePath,
  });

  bool get canInstallAutomatically =>
      updateAvailable &&
      asset != null &&
      packageType != UpdatePackageType.manual &&
      packageType != UpdatePackageType.unsupported &&
      channel == UpdateBuildChannel.stable;

  UpdateState copyWith({
    String? currentVersion,
    String? latestVersion,
    UpdateBuildChannel? channel,
    UpdatePlatform? platform,
    UpdatePackageType? packageType,
    UpdateStage? stage,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    bool? updateAvailable,
    String? statusMessage,
    String? errorMessage,
    bool clearError = false,
    UpdateRelease? release,
    UpdateAsset? asset,
    bool clearAsset = false,
    String? downloadedFilePath,
    bool clearDownloadedFile = false,
  }) {
    return UpdateState(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      channel: channel ?? this.channel,
      platform: platform ?? this.platform,
      packageType: packageType ?? this.packageType,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      release: release ?? this.release,
      asset: clearAsset ? null : asset ?? this.asset,
      downloadedFilePath: clearDownloadedFile
          ? null
          : downloadedFilePath ?? this.downloadedFilePath,
    );
  }
}

class UpdateRuntime {
  final UpdatePlatform platform;
  final bool isDebug;
  final Map<String, String> environment;
  final String executablePath;
  final int processId;

  const UpdateRuntime({
    required this.platform,
    required this.isDebug,
    required this.environment,
    required this.executablePath,
    required this.processId,
  });

  factory UpdateRuntime.current() {
    return UpdateRuntime(
      platform: Platform.isWindows
          ? UpdatePlatform.windows
          : Platform.isLinux
          ? UpdatePlatform.linux
          : UpdatePlatform.unsupported,
      isDebug: kDebugMode,
      environment: Platform.environment,
      executablePath: Platform.resolvedExecutable,
      processId: pid,
    );
  }
}

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef ProcessStarter =
    Future<void> Function(
      String executable,
      List<String> arguments,
      ProcessStartMode mode,
    );
typedef TemporaryDirectoryLoader = Future<Directory> Function();
typedef LogsDirectoryLoader = Future<String> Function();

class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'Update download cancelled.';
}

class UpdateService extends ChangeNotifier {
  UpdateService({
    http.Client? client,
    PackageInfoLoader? packageInfoLoader,
    UpdateRuntime? runtime,
    ProcessRunner? processRunner,
    ProcessStarter? processStarter,
    TemporaryDirectoryLoader? temporaryDirectoryLoader,
    LogsDirectoryLoader? logsDirectoryLoader,
  }) : _client = client ?? http.Client(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _runtime = runtime ?? UpdateRuntime.current(),
       _processRunner =
           processRunner ??
           ((executable, arguments) => Process.run(executable, arguments)),
       _processStarter =
           processStarter ??
           ((executable, arguments, mode) async {
             await Process.start(executable, arguments, mode: mode);
           }),
       _temporaryDirectoryLoader =
           temporaryDirectoryLoader ?? getTemporaryDirectory,
       _logsDirectoryLoader =
           logsDirectoryLoader ?? LogService.getLogsDirectory;

  static final UpdateService instance = UpdateService();

  final http.Client _client;
  final PackageInfoLoader _packageInfoLoader;
  final UpdateRuntime _runtime;
  final ProcessRunner _processRunner;
  final ProcessStarter _processStarter;
  final TemporaryDirectoryLoader _temporaryDirectoryLoader;
  final LogsDirectoryLoader _logsDirectoryLoader;

  UpdateState _state = const UpdateState();
  bool _initialized = false;
  bool _cancelRequested = false;

  UpdateState get state => _state;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final environment = await _detectEnvironment();
      _setState(
        _state.copyWith(
          currentVersion: environment.version,
          channel: environment.channel,
          platform: _runtime.platform,
          packageType: environment.packageType,
          statusMessage: 'Ready to check for updates.',
        ),
      );
      await _consumeCompletionMarker();
    } catch (error, stackTrace) {
      _setState(
        _state.copyWith(
          platform: _runtime.platform,
          packageType: _runtime.platform == UpdatePlatform.windows
              ? UpdatePackageType.windowsInstaller
              : UpdatePackageType.manual,
          channel: _runtime.isDebug
              ? UpdateBuildChannel.localDebug
              : UpdateBuildChannel.development,
          statusMessage:
              'Version detection is unavailable. HardwareMon can still run.',
          errorMessage: error.toString(),
        ),
      );
      await _log('Updater initialization failed: $error\n$stackTrace');
    }
  }

  Future<UpdateState> checkForUpdates() async {
    await initialize();
    if (_state.stage.isBusy) return _state;

    _cancelRequested = false;
    _setState(
      _state.copyWith(
        stage: UpdateStage.checking,
        progress: 0.04,
        statusMessage: 'Contacting GitHub Releases…',
        updateAvailable: false,
        clearError: true,
        clearAsset: true,
        clearDownloadedFile: true,
      ),
    );

    try {
      final environment = await _detectEnvironment();
      _setState(
        _state.copyWith(
          currentVersion: environment.version,
          channel: environment.channel,
          packageType: environment.packageType,
          progress: 0.18,
          statusMessage: 'Reading the latest release metadata…',
        ),
      );

      final response = await _client
          .get(
            Uri.parse(_githubLatestReleaseUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'HardwareMon-Updater',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw _githubApiError(response);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('GitHub returned invalid release data.');
      }

      final release = UpdateRelease.fromJson(decoded);
      if (release.version.isEmpty) {
        throw const FormatException('The latest release has no valid version.');
      }

      final asset = matchingAssetFor(release.assets, environment.packageType);
      final comparison = compareVersions(environment.version, release.version);
      final updateAvailable =
          environment.channel == UpdateBuildChannel.stable && comparison < 0;

      final message = _checkedStatusMessage(
        channel: environment.channel,
        packageType: environment.packageType,
        updateAvailable: updateAvailable,
        hasMatchingAsset: asset != null,
        latestVersion: release.version,
        comparison: comparison,
      );

      _setState(
        _state.copyWith(
          latestVersion: release.version,
          release: release,
          asset: asset,
          stage: updateAvailable ? UpdateStage.available : UpdateStage.idle,
          progress: updateAvailable ? 0.2 : 1,
          updateAvailable: updateAvailable,
          statusMessage: message,
          clearError: true,
        ),
      );
      await _log(
        'Update check complete: current=${environment.version}, '
        'latest=${release.version}, channel=${environment.channel.name}, '
        'package=${environment.packageType.name}, available=$updateAvailable, '
        'asset=${asset?.name ?? "none"}',
      );
      return _state;
    } catch (error, stackTrace) {
      await _fail('Unable to check for updates.', error, stackTrace);
      return _state;
    }
  }

  Future<void> performUpdate({
    required Future<void> Function() closeApplication,
  }) async {
    if (!_state.canInstallAutomatically || _state.asset == null) {
      await _fail(
        'This installation requires a manual update.',
        StateError('No safe automatic update path is available.'),
        StackTrace.current,
      );
      return;
    }

    try {
      final packageFile = await downloadUpdate();
      if (_cancelRequested) throw const UpdateCancelledException();
      await installUpdate(packageFile, closeApplication: closeApplication);
    } on UpdateCancelledException catch (error) {
      _setState(
        _state.copyWith(
          stage: UpdateStage.available,
          progress: 0.2,
          downloadedBytes: 0,
          totalBytes: _state.asset?.size ?? 0,
          statusMessage: 'Download cancelled. HardwareMon was not changed.',
          errorMessage: error.toString(),
          clearDownloadedFile: true,
        ),
      );
      await _log(error.toString());
    } catch (error, stackTrace) {
      if (_state.stage != UpdateStage.restarting) {
        await _cleanupDownloadedUpdate();
      }
      await _fail('The update could not be completed.', error, stackTrace);
    }
  }

  Future<File> downloadUpdate() async {
    final asset = _state.asset;
    if (asset == null || !_assetMatchesPackage(asset, _state.packageType)) {
      throw StateError('The release asset does not match this installation.');
    }
    if (asset.size < 64 * 1024) {
      throw StateError('The release asset is unexpectedly small.');
    }

    _cancelRequested = false;
    final tempRoot = await _temporaryDirectoryLoader();
    final updateDirectory = Directory(
      _joinPath(
        tempRoot.path,
        'HardwareMon',
        'updates',
        _safeFileName(_state.latestVersion),
      ),
    );
    if (await updateDirectory.exists()) {
      await updateDirectory.delete(recursive: true);
    }
    await updateDirectory.create(recursive: true);

    final target = File(_joinPath(updateDirectory.path, asset.name));
    _setState(
      _state.copyWith(
        stage: UpdateStage.downloading,
        progress: 0,
        downloadedBytes: 0,
        totalBytes: asset.size,
        statusMessage: 'Downloading ${asset.name}…',
        clearError: true,
      ),
    );

    try {
      final request = http.Request('GET', asset.downloadUrl)
        ..headers.addAll(const {
          'Accept': 'application/octet-stream',
          'User-Agent': 'HardwareMon-Updater',
        });
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with HTTP ${response.statusCode}.',
          uri: asset.downloadUrl,
        );
      }

      final expectedSize = asset.size > 0
          ? asset.size
          : response.contentLength ?? 0;
      var received = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (_cancelRequested) throw const UpdateCancelledException();
          sink.add(chunk);
          received += chunk.length;
          final progress = expectedSize > 0
              ? (received / expectedSize).clamp(0.0, 1.0)
              : 0.0;
          _setState(
            _state.copyWith(
              progress: progress,
              downloadedBytes: received,
              totalBytes: expectedSize,
              statusMessage:
                  'Downloading ${asset.name} · ${_formatBytes(received)} '
                  'of ${_formatBytes(expectedSize)}',
            ),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (_cancelRequested) throw const UpdateCancelledException();

      _setState(
        _state.copyWith(
          stage: UpdateStage.verifying,
          progress: 1,
          statusMessage: 'Verifying the downloaded package…',
        ),
      );

      if (!await target.exists()) {
        throw StateError('The downloaded update file is missing.');
      }
      final actualSize = await target.length();
      if (actualSize < 64 * 1024) {
        throw StateError('The downloaded update is unexpectedly small.');
      }
      if (asset.size > 0 && actualSize != asset.size) {
        throw StateError(
          'Download verification failed: expected ${asset.size} bytes, '
          'received $actualSize bytes.',
        );
      }

      _setState(
        _state.copyWith(
          downloadedFilePath: target.path,
          statusMessage: 'Download verified. Preparing installation…',
        ),
      );
      await _log(
        'Downloaded and verified ${asset.name} ($actualSize bytes) to '
        '${target.path}',
      );
      return target;
    } catch (_) {
      if (await updateDirectory.exists()) {
        await updateDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  void cancelDownload() {
    if (_state.stage == UpdateStage.downloading) {
      _cancelRequested = true;
      _setState(_state.copyWith(statusMessage: 'Cancelling download safely…'));
    }
  }

  Future<void> installUpdate(
    File packageFile, {
    required Future<void> Function() closeApplication,
  }) async {
    if (!await packageFile.exists()) {
      throw StateError('The update package no longer exists.');
    }
    final asset = _state.asset;
    if (asset == null ||
        packageFile.path != _state.downloadedFilePath ||
        !_assetMatchesPackage(asset, _state.packageType)) {
      throw StateError('The update package failed its platform safety check.');
    }

    final marker = await _completionMarkerFile();
    await marker.parent.create(recursive: true);
    if (await marker.exists()) await marker.delete();

    _setState(
      _state.copyWith(
        stage: UpdateStage.installing,
        progress: 1,
        statusMessage:
            'Installing HardwareMon ${_state.latestVersion}. '
            'A system permission prompt may appear.',
        clearError: true,
      ),
    );

    if (_state.packageType == UpdatePackageType.windowsInstaller) {
      final helper = await _writeWindowsHelper(
        packageFile: packageFile,
        marker: marker,
      );
      final launcher = await _writeWindowsLauncher(packageFile.parent);
      await _processStarter('wscript.exe', [
        launcher.path,
        helper.path,
        packageFile.path,
        _runtime.executablePath,
        '${_runtime.processId}',
        marker.path,
        _state.latestVersion,
      ], ProcessStartMode.detached);
    } else {
      final helper = await _writeLinuxHelper(
        packageFile: packageFile,
        marker: marker,
      );
      await _processStarter('/bin/sh', [
        helper.path,
        packageFile.path,
        '${_runtime.processId}',
        marker.path,
        _state.latestVersion,
        _state.packageType.name,
      ], ProcessStartMode.detached);
    }

    _setState(
      _state.copyWith(
        stage: UpdateStage.restarting,
        statusMessage:
            'HardwareMon will close now and restart after installation.',
      ),
    );
    await _log(
      'Installer helper launched for ${_state.packageType.name}; '
      'closing PID ${_runtime.processId}.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await closeApplication();
  }

  Future<void> openReleasePage() async {
    final url =
        _state.release?.htmlUrl.toString() ??
        'https://github.com/louisboii747/HardwareMon/releases/latest';
    try {
      if (_runtime.platform == UpdatePlatform.windows) {
        await _processRunner('explorer.exe', [url]);
      } else if (_runtime.platform == UpdatePlatform.linux) {
        await _processRunner('xdg-open', [url]);
      } else {
        throw UnsupportedError('This platform cannot open release links.');
      }
    } catch (error, stackTrace) {
      await _fail('Unable to open the release page.', error, stackTrace);
    }
  }

  static UpdateAsset? matchingAssetFor(
    List<UpdateAsset> assets,
    UpdatePackageType packageType,
  ) {
    final extension = switch (packageType) {
      UpdatePackageType.windowsInstaller => '.exe',
      UpdatePackageType.deb => '.deb',
      UpdatePackageType.rpm => '.rpm',
      _ => null,
    };
    if (extension == null) return null;

    final matches = assets
        .where((asset) => asset.name.toLowerCase().endsWith(extension))
        .toList(growable: false);
    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final aHardwareMon = a.name.toLowerCase().contains('hardwaremon') ? 0 : 1;
      final bHardwareMon = b.name.toLowerCase().contains('hardwaremon') ? 0 : 1;
      return aHardwareMon.compareTo(bHardwareMon);
    });
    return matches.first;
  }

  static UpdateBuildChannel detectBuildChannel({
    required String version,
    required bool isDebug,
  }) {
    if (isDebug) return UpdateBuildChannel.localDebug;
    final normalized = normalizeVersion(version).toLowerCase();
    if (normalized.isEmpty ||
        normalized.contains('dev') ||
        normalized.contains('debug') ||
        normalized.contains('local') ||
        normalized.contains('alpha') ||
        normalized.contains('beta') ||
        normalized.contains('rc') ||
        normalized.contains('snapshot') ||
        normalized.contains('nightly') ||
        normalized.contains('-')) {
      return UpdateBuildChannel.development;
    }
    return _SemanticVersion.tryParse(normalized) == null
        ? UpdateBuildChannel.development
        : UpdateBuildChannel.stable;
  }

  static int compareVersions(String left, String right) {
    final leftVersion = _SemanticVersion.tryParse(normalizeVersion(left));
    final rightVersion = _SemanticVersion.tryParse(normalizeVersion(right));
    if (leftVersion == null || rightVersion == null) {
      return normalizeVersion(left).compareTo(normalizeVersion(right));
    }
    return leftVersion.compareTo(rightVersion);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<_DetectedEnvironment> _detectEnvironment() async {
    final packageInfo = await _packageInfoLoader();
    final metadataVersion = normalizeVersion(packageInfo.version);
    final compiledVersion = normalizeVersion(_compiledAppVersion);
    var version = compiledVersion.isNotEmpty && compiledVersion != 'dev build'
        ? compiledVersion
        : metadataVersion;
    var packageType = UpdatePackageType.unsupported;

    if (_runtime.platform == UpdatePlatform.windows) {
      packageType = UpdatePackageType.windowsInstaller;
    } else if (_runtime.platform == UpdatePlatform.linux) {
      final linuxPackage = await _detectLinuxPackage();
      packageType = linuxPackage.type;
      if ((compiledVersion.isEmpty || compiledVersion == 'dev build') &&
          linuxPackage.version != null &&
          linuxPackage.version!.trim().isNotEmpty) {
        version = normalizePackageVersion(
          linuxPackage.version!,
          linuxPackage.type,
        );
      }
    }

    if (version.isEmpty) version = 'dev build';
    return _DetectedEnvironment(
      version: version,
      channel: detectBuildChannel(version: version, isDebug: _runtime.isDebug),
      packageType: packageType,
    );
  }

  Future<_DetectedLinuxPackage> _detectLinuxPackage() async {
    if (_runtime.environment['FLATPAK_ID']?.isNotEmpty == true) {
      return const _DetectedLinuxPackage(UpdatePackageType.manual);
    }

    try {
      final result = await _processRunner('dpkg-query', [
        '-W',
        '-f=\${Status}\n\${Version}',
        'hardwaremon',
      ]);
      final output = result.stdout.toString().trim();
      if (result.exitCode == 0 && output.contains('install ok installed')) {
        final lines = output.split(RegExp(r'\r?\n'));
        return _DetectedLinuxPackage(
          UpdatePackageType.deb,
          version: lines.length > 1 ? lines.last.trim() : null,
        );
      }
    } catch (_) {
      // Continue to RPM detection.
    }

    try {
      final result = await _processRunner('rpm', [
        '-q',
        '--qf',
        '%{VERSION}',
        'hardwaremon',
      ]);
      if (result.exitCode == 0) {
        return _DetectedLinuxPackage(
          UpdatePackageType.rpm,
          version: result.stdout.toString().trim(),
        );
      }
    } catch (_) {
      // Fall back to manual updates.
    }

    return const _DetectedLinuxPackage(UpdatePackageType.manual);
  }

  Future<File> _writeWindowsHelper({
    required File packageFile,
    required File marker,
  }) async {
    final helper = File(
      _joinPath(packageFile.parent.path, 'install-update.ps1'),
    );
    await helper.writeAsString(r'''
param(
  [Parameter(Mandatory=$true)][string]$PackagePath,
  [Parameter(Mandatory=$true)][string]$AppPath,
  [Parameter(Mandatory=$true)][int]$AppPid,
  [Parameter(Mandatory=$true)][string]$MarkerPath,
  [Parameter(Mandatory=$true)][string]$Version
)

$ErrorActionPreference = "Stop"
$status = "failed"
$message = "The installer did not complete."
$logPath = Join-Path (Split-Path -Parent $MarkerPath) "updater-helper.log"

function Write-UpdateLog([string]$Text) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null
  Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) $Text"
}

try {
  Write-UpdateLog "Helper started for version $Version; waiting for PID $AppPid."
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Process -Id $AppPid -ErrorAction SilentlyContinue) -and
         ((Get-Date) -lt $deadline)) {
    Start-Sleep -Milliseconds 250
  }

  if (Get-Process -Id $AppPid -ErrorAction SilentlyContinue) {
    throw "HardwareMon did not exit within 90 seconds."
  }

  Write-UpdateLog "Starting installer $PackagePath."
  $installer = Start-Process `
    -FilePath $PackagePath `
    -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS", "/SP-") `
    -Verb RunAs `
    -Wait `
    -PassThru

  if ($installer.ExitCode -eq 0) {
    $status = "success"
    $message = "HardwareMon was updated successfully."
    Write-UpdateLog $message
  }
  else {
    $message = "The installer exited with code $($installer.ExitCode)."
    Write-UpdateLog $message
  }
}
catch {
  $message = $_.Exception.Message
  Write-UpdateLog "Update failed: $message"
}

New-Item -ItemType Directory -Path (Split-Path $MarkerPath) -Force | Out-Null
$temporaryMarker = "$MarkerPath.tmp"
Set-Content -LiteralPath $temporaryMarker -Value @($status, $Version, $message)
Move-Item -LiteralPath $temporaryMarker -Destination $MarkerPath -Force

if (Test-Path -LiteralPath $AppPath) {
  Write-UpdateLog "Restarting HardwareMon from $AppPath."
  Start-Process -FilePath $AppPath -WorkingDirectory (Split-Path -Parent $AppPath)
}
else {
  Write-UpdateLog "Restart skipped because the application path is missing: $AppPath"
}

Remove-Item -LiteralPath $PackagePath -Force -ErrorAction SilentlyContinue
''');
    return helper;
  }

  Future<File> _writeWindowsLauncher(Directory updateDirectory) async {
    final launcher = File(_joinPath(updateDirectory.path, 'launch-update.vbs'));
    await launcher.writeAsString(r'''
Option Explicit

Function QuoteArgument(value)
  QuoteArgument = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function

Dim shell
Dim command
Dim index

Set shell = CreateObject("WScript.Shell")
command = "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & QuoteArgument(WScript.Arguments(0))

For index = 1 To WScript.Arguments.Count - 1
  command = command & " " & QuoteArgument(WScript.Arguments(index))
Next

shell.Run command, 0, False
''');
    return launcher;
  }

  Future<File> _writeLinuxHelper({
    required File packageFile,
    required File marker,
  }) async {
    final helper = File(
      _joinPath(packageFile.parent.path, 'install-update.sh'),
    );
    await helper.writeAsString(r'''#!/bin/sh
PACKAGE_PATH="$1"
APP_PID="$2"
MARKER_PATH="$3"
VERSION="$4"
PACKAGE_TYPE="$5"
LOG_PATH="$(dirname "$MARKER_PATH")/updater-helper.log"

log_update() {
  mkdir -p "$(dirname "$LOG_PATH")"
  printf '%s %s\n' "$(date -Iseconds)" "$1" >> "$LOG_PATH"
}

log_update "Helper started for version $VERSION; waiting for PID $APP_PID."
WAIT_COUNT=0
while kill -0 "$APP_PID" 2>/dev/null && [ "$WAIT_COUNT" -lt 360 ]; do
  sleep 0.25
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

STATUS="failed"
MESSAGE="The package installer did not complete."

if kill -0 "$APP_PID" 2>/dev/null; then
  EXIT_CODE=124
  MESSAGE="HardwareMon did not exit within 90 seconds."
elif ! command -v pkexec >/dev/null 2>&1; then
  EXIT_CODE=127
  MESSAGE="pkexec is required to install system packages."
elif [ "$PACKAGE_TYPE" = "deb" ]; then
  log_update "Installing DEB package $PACKAGE_PATH."
  if command -v apt >/dev/null 2>&1; then
    pkexec apt install -y "$PACKAGE_PATH"
    EXIT_CODE=$?
  else
    pkexec dpkg -i "$PACKAGE_PATH"
    EXIT_CODE=$?
  fi
elif [ "$PACKAGE_TYPE" = "rpm" ]; then
  log_update "Installing RPM package $PACKAGE_PATH."
  if command -v dnf >/dev/null 2>&1; then
    pkexec dnf install -y "$PACKAGE_PATH"
    EXIT_CODE=$?
  elif command -v zypper >/dev/null 2>&1; then
    pkexec zypper --non-interactive install "$PACKAGE_PATH"
    EXIT_CODE=$?
  else
    pkexec rpm -U "$PACKAGE_PATH"
    EXIT_CODE=$?
  fi
else
  EXIT_CODE=2
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  STATUS="success"
  MESSAGE="HardwareMon was updated successfully."
elif [ "$EXIT_CODE" -ne 124 ] && [ "$EXIT_CODE" -ne 127 ]; then
  MESSAGE="The package installer exited with code $EXIT_CODE."
fi

mkdir -p "$(dirname "$MARKER_PATH")"
TEMP_MARKER="$MARKER_PATH.tmp"
printf '%s\n%s\n%s\n' "$STATUS" "$VERSION" "$MESSAGE" > "$TEMP_MARKER"
mv -f "$TEMP_MARKER" "$MARKER_PATH"
log_update "$MESSAGE"

if [ -x /usr/bin/hardwaremon ]; then
  log_update "Restarting HardwareMon from /usr/bin/hardwaremon."
  nohup /usr/bin/hardwaremon >/dev/null 2>&1 </dev/null &
else
  log_update "Restart skipped because /usr/bin/hardwaremon is missing."
fi

rm -f -- "$PACKAGE_PATH"
''');
    return helper;
  }

  Future<File> _completionMarkerFile() async {
    final logsDirectory = await _logsDirectoryLoader();
    return File(_joinPath(logsDirectory, 'update-result.txt'));
  }

  Future<void> _consumeCompletionMarker() async {
    try {
      final marker = await _completionMarkerFile();
      if (!await marker.exists()) return;
      final lines = await marker.readAsLines();
      await marker.delete();
      if (lines.isEmpty) return;

      final success = lines.first.trim() == 'success';
      final version = lines.length > 1
          ? lines[1].trim()
          : _state.currentVersion;
      final message = lines.length > 2
          ? lines.sublist(2).join('\n').trim()
          : success
          ? 'HardwareMon was updated successfully.'
          : 'The previous update did not complete.';

      _setState(
        _state.copyWith(
          currentVersion: success ? version : _state.currentVersion,
          latestVersion: version,
          stage: success ? UpdateStage.complete : UpdateStage.failed,
          progress: success ? 1 : 0,
          updateAvailable: false,
          statusMessage: message,
          errorMessage: success ? null : message,
          clearError: success,
        ),
      );
      await _log('Consumed updater result: success=$success, $message');
    } catch (error, stackTrace) {
      await _log('Failed to read updater result: $error\n$stackTrace');
    }
  }

  String _checkedStatusMessage({
    required UpdateBuildChannel channel,
    required UpdatePackageType packageType,
    required bool updateAvailable,
    required bool hasMatchingAsset,
    required String latestVersion,
    required int comparison,
  }) {
    if (channel == UpdateBuildChannel.localDebug) {
      return 'Local debug builds are not compared as installed releases.';
    }
    if (channel == UpdateBuildChannel.development) {
      return comparison < 0
          ? 'Stable $latestVersion is newer, but development builds are not '
                'automatically replaced.'
          : 'This development build is ahead of or equivalent to stable '
                '$latestVersion.';
    }
    if (!updateAvailable) {
      return 'HardwareMon is up to date.';
    }
    if (packageType == UpdatePackageType.manual || !hasMatchingAsset) {
      return 'A newer release is available, but this installation must be '
          'updated manually.';
    }
    return 'HardwareMon $latestVersion is ready to install.';
  }

  String _githubApiError(http.Response response) {
    if (response.statusCode == 403 &&
        response.headers['x-ratelimit-remaining'] == '0') {
      final resetSeconds = int.tryParse(
        response.headers['x-ratelimit-reset'] ?? '',
      );
      final reset = resetSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              resetSeconds * 1000,
              isUtc: true,
            ).toLocal();
      return reset == null
          ? 'GitHub API rate limit reached. Please try again later.'
          : 'GitHub API rate limit reached. Try again after $reset.';
    }
    return 'GitHub Releases returned HTTP ${response.statusCode}.';
  }

  bool _assetMatchesPackage(UpdateAsset asset, UpdatePackageType packageType) {
    return identical(matchingAssetFor([asset], packageType), asset);
  }

  Future<void> _fail(
    String userMessage,
    Object error,
    StackTrace stackTrace,
  ) async {
    final detail = error.toString();
    _setState(
      _state.copyWith(
        stage: UpdateStage.failed,
        progress: 0,
        statusMessage: userMessage,
        errorMessage: detail,
      ),
    );
    await _log('$userMessage $detail\n$stackTrace');
  }

  Future<void> _cleanupDownloadedUpdate() async {
    final path = _state.downloadedFilePath;
    if (path == null) return;
    try {
      final directory = File(path).parent;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (error) {
      await _log('Failed to clean update files: $error');
    }
  }

  Future<void> _log(String message) async {
    try {
      final logsDirectory = await _logsDirectoryLoader();
      final directory = Directory(logsDirectory);
      await directory.create(recursive: true);
      final file = File(_joinPath(logsDirectory, 'updater.log'));
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} $message${Platform.lineTerminator}',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      debugPrint('Updater log: $message');
    }
  }

  void _setState(UpdateState value) {
    _state = value;
    notifyListeners();
  }

  String _joinPath(
    String first,
    String second, [
    String? third,
    String? fourth,
  ]) {
    final separator = _runtime.platform == UpdatePlatform.windows ? r'\' : '/';
    return [
      first,
      second,
      third,
      fourth,
    ].whereType<String>().where((part) => part.isNotEmpty).join(separator);
  }

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return 'unknown size';
    const megabyte = 1024 * 1024;
    if (bytes >= megabyte) return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    const kilobyte = 1024;
    return '${(bytes / kilobyte).toStringAsFixed(0)} KB';
  }
}

class _DetectedEnvironment {
  final String version;
  final UpdateBuildChannel channel;
  final UpdatePackageType packageType;

  const _DetectedEnvironment({
    required this.version,
    required this.channel,
    required this.packageType,
  });
}

class _DetectedLinuxPackage {
  final UpdatePackageType type;
  final String? version;

  const _DetectedLinuxPackage(this.type, {this.version});
}

class _SemanticVersion implements Comparable<_SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  const _SemanticVersion(this.major, this.minor, this.patch, this.preRelease);

  static _SemanticVersion? tryParse(String input) {
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(input.trim());
    if (match == null) return null;
    return _SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4)?.split('.') ?? const [],
    );
  }

  @override
  int compareTo(_SemanticVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final comparison = pair.$1.compareTo(pair.$2);
      if (comparison != 0) return comparison;
    }
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;

    final length = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < length; index++) {
      if (index >= preRelease.length) return -1;
      if (index >= other.preRelease.length) return 1;
      final left = preRelease[index];
      final right = other.preRelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final comparison = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftNumber != null
          ? -1
          : rightNumber != null
          ? 1
          : left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}

String normalizeVersion(String value) {
  var normalized = value.trim();
  if (normalized.toLowerCase().startsWith('version ')) {
    normalized = normalized.substring(8).trim();
  }
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1);
  }
  final epochSeparator = normalized.indexOf(':');
  if (epochSeparator >= 0) {
    normalized = normalized.substring(epochSeparator + 1);
  }
  return normalized;
}

String normalizePackageVersion(String value, UpdatePackageType packageType) {
  final normalized = normalizeVersion(value);
  if (packageType != UpdatePackageType.deb) return normalized;

  final stableWithDebianRevision = RegExp(
    r'^(\d+\.\d+\.\d+)-\d+(?:[.+~].*)?$',
  ).firstMatch(normalized);
  return stableWithDebianRevision?.group(1) ?? normalized;
}
