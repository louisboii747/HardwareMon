import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/log_service.dart';
import '../windows_ui/core/backend_config.dart';
import '../windows_ui/services/settings_service.dart';
import 'bug_report_models.dart';
import 'github_auth.dart';
import 'report_redactor.dart';

typedef ReportProgress = void Function(String message, double progress);

abstract interface class IBugReportProvider {
  String get name;
  Future<BugReportSubmissionResult> submit(
    BugReportBundle bundle, {
    ReportProgress? onProgress,
  });
}

abstract interface class IBugReportService {
  Future<BugReportBundle> prepare(
    BugReportDraft draft, {
    ReportProgress? onProgress,
  });
  Future<BugReportSubmissionResult> submit(
    BugReportBundle bundle, {
    ReportProgress? onProgress,
  });
}

class BugReportProviderException implements Exception {
  const BugReportProviderException(this.message, {this.retryAfter});
  final String message;
  final Duration? retryAfter;
  @override
  String toString() => message;
}

class DiagnosticsCollector {
  DiagnosticsCollector({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, Object?>> collect(Set<DiagnosticSection> sections) async {
    final package = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final output = <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': now.toUtc().toIso8601String(),
      'hardwaremonVersion': package.version,
      'buildNumber': package.buildNumber,
      'buildMode': const bool.fromEnvironment('dart.vm.product')
          ? 'release'
          : 'debug',
      'commitHash': const String.fromEnvironment(
        'HARDWAREMON_COMMIT_HASH',
        defaultValue: 'not embedded',
      ),
      'releaseChannel': const String.fromEnvironment(
        'HARDWAREMON_RELEASE_CHANNEL',
        defaultValue: 'development',
      ),
    };

    if (sections.contains(DiagnosticSection.systemInformation)) {
      output['system'] = {
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'timezone': now.timeZoneName,
        'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
        'processors': Platform.numberOfProcessors,
      };
    }
    if (sections.contains(DiagnosticSection.applicationSettings)) {
      final settings = await SettingsService().loadSettings();
      output['settings'] = {
        'theme': settings.theme,
        'refreshInterval': settings.refreshInterval,
        'launchOnStartup': settings.launchOnStartup,
        'minimiseToTray': settings.minimiseToTray,
        'closeToTray': settings.closeToTray,
        'historicalMonitoring': settings.historicalMonitoring,
        'cpuAlerts': settings.cpuAlerts,
        'ramAlerts': settings.ramAlerts,
        'temperatureAlerts': settings.temperatureAlerts,
        'diskAlerts': settings.diskAlerts,
        'alertSounds': settings.alertSounds,
        'autoUpdateChecks': settings.autoUpdateChecks,
      };
    }
    if (sections.contains(DiagnosticSection.hardwareInformation) ||
        sections.contains(DiagnosticSection.recentTelemetry)) {
      try {
        final response = await _client
            .get(Uri.parse('${BackendConfig.baseUrl}/stats'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = Map<String, dynamic>.from(
            jsonDecode(response.body) as Map,
          );
          output['hardware'] = _hardwareOnly(data);
          if (sections.contains(DiagnosticSection.recentTelemetry)) {
            output['telemetry'] = data;
          }
        } else {
          output['telemetryError'] = 'Backend returned ${response.statusCode}';
        }
      } catch (error) {
        output['telemetryError'] = error.toString();
      }
    }
    return output;
  }

  Map<String, Object?> _hardwareOnly(Map<String, dynamic> data) => {
    for (final key in const [
      'cpu_name',
      'cpu_cores',
      'cpu_threads',
      'cpu_clock',
      'ram_total',
      'ram_available',
      'gpu_name',
      'gpu_driver',
      'gpu_vram_total',
      'platform',
      'storage',
      'capabilities',
      'telemetry_provider',
      'loaded_modules',
    ])
      if (data.containsKey(key)) key: data[key],
  };
}

class LogCollector {
  const LogCollector({this.maxTotalBytes = 4 * 1024 * 1024});
  final int maxTotalBytes;

  Future<Map<String, String>> collect() async {
    final result = <String, String>{};
    String directory;
    try {
      directory = await LogService.getLogsDirectory();
    } catch (_) {
      return result;
    }
    final root = Directory(directory);
    if (!await root.exists()) return result;
    final files = await root
        .list()
        .where((item) => item is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    var remaining = maxTotalBytes;
    for (final file in files) {
      if (remaining <= 0) break;
      try {
        final bytes = await file.readAsBytes();
        final take = bytes.length > remaining ? remaining : bytes.length;
        final tail = bytes.sublist(bytes.length - take);
        result[file.uri.pathSegments.last] = utf8.decode(
          tail,
          allowMalformed: true,
        );
        remaining -= take;
      } catch (_) {
        // A locked or binary log must not prevent the rest of the report.
      }
    }
    return result;
  }
}

class ScreenshotCollector {
  const ScreenshotCollector();
  static const supportedExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  bool isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any(lower.endsWith);
  }

  Future<String> saveCaptured(Uint8List bytes) async {
    final root = await getTemporaryDirectory();
    final file = File(
      '${root.path}${Platform.pathSeparator}hardwaremon-screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

class CrashCollector {
  static Future<File> get marker async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}${Platform.pathSeparator}pending-crash.json');
  }

  static Future<void> record(Object error, StackTrace stack) async {
    final file = await marker;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'exception': error.toString(),
        'stackTrace': stack.toString(),
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
      }),
      flush: true,
    );
  }

  static Future<String?> consume() async {
    final file = await marker;
    if (!await file.exists()) return null;
    final value = await file.readAsString();
    await file.delete();
    return value;
  }
}

class BugReportBuilder {
  BugReportBuilder({ReportRedactor? redactor})
    : redactor = redactor ?? ReportRedactor();
  final ReportRedactor redactor;

  String markdown(BugReportDraft draft, Map<String, Object?> diagnostics) {
    final steps = draft.steps.where((item) => item.trim().isNotEmpty).toList();
    final system = diagnostics['system'] as Map?;
    final safeSteps = steps.map(redactor.redact).toList();
    final expected = redactor.redact(draft.expectedBehaviour.trim());
    final actual = redactor.redact(draft.actualBehaviour.trim());
    final details = _bounded(redactor.prettyJson(diagnostics), 18000);
    return '''## Description
${redactor.redact(draft.description.trim())}

## Steps to reproduce
${safeSteps.isEmpty ? '_Not provided_' : List.generate(safeSteps.length, (index) => '${index + 1}. ${safeSteps[index]}').join('\n')}

## Expected behaviour
${expected.isEmpty ? '_Not provided_' : expected}

## Actual behaviour
${actual.isEmpty ? '_Not provided_' : actual}

## Severity
${draft.severity.displayName}

## HardwareMon build
| Field | Value |
|---|---|
| Version | ${diagnostics['hardwaremonVersion']} |
| Build | ${diagnostics['buildNumber']} |
| Commit | ${diagnostics['commitHash']} |
| Channel | ${diagnostics['releaseChannel']} |
| Platform | ${system?['platform'] ?? 'Not included'} |

## Diagnostics
<details>
<summary>View diagnostics</summary>

```json
$details
```
</details>

---
Submitted from HardwareMon's built-in bug reporter.  
Report ID: ${diagnostics['reportId'] ?? 'HM-UNKNOWN'}
''';
  }

  String _bounded(String value, int limit) {
    if (value.length <= limit) return value;
    final cut = value.lastIndexOf('\n', limit);
    return '${value.substring(0, cut > 0 ? cut : limit)}\n... <truncated by HardwareMon>';
  }
}

class ReportCompressor {
  const ReportCompressor();

  Future<void> compress(String sourceDirectory, String destination) async {
    final archive = Archive();
    final source = Directory(sourceDirectory);
    await for (final entity in source.list(recursive: true)) {
      if (entity is! File || entity.path == destination) continue;
      final relative = entity.path
          .substring(source.path.length + 1)
          .replaceAll('\\', '/');
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    await File(destination).writeAsBytes(encoded, flush: true);
  }
}

class PendingReportManager {
  Future<Directory> get root async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}bug-reports',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> get _index async =>
      File('${(await root).path}${Platform.pathSeparator}pending-reports.json');

  Future<List<PendingBugReport>> list() async {
    try {
      final file = await _index;
      if (!await file.exists()) return [];
      final values = jsonDecode(await file.readAsString()) as List;
      return values
          .map(
            (item) => PendingBugReport.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(PendingBugReport report) async {
    final reports = await list();
    reports.removeWhere((item) => item.id == report.id);
    reports.add(report);
    await _write(reports);
  }

  Future<void> delete(PendingBugReport report) async {
    final reports = await list()
      ..removeWhere((item) => item.id == report.id);
    final directory = Directory(report.directoryPath);
    if (await directory.exists()) await directory.delete(recursive: true);
    await _write(reports);
  }

  Future<void> _write(List<PendingBugReport> reports) async {
    final file = await _index;
    await file.writeAsString(
      jsonEncode(reports.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}

class GitHubBugProvider implements IBugReportProvider {
  GitHubBugProvider({
    required this.config,
    required this.auth,
    required this.api,
  });

  final GitHubBugReportingConfig config;
  final GitHubAuthService auth;
  final GitHubApiClient api;
  DateTime? _labelsFetchedAt;
  Set<String> _labels = {};
  @override
  String get name => 'GitHub Issues';

  @override
  Future<BugReportSubmissionResult> submit(
    BugReportBundle bundle, {
    ReportProgress? onProgress,
  }) async {
    if (!config.isConfigured) {
      throw GitHubApiException(config.configurationMessage);
    }
    final token = await auth.getValidAccessToken();
    if (token == null) {
      throw const GitHubApiException(
        'Sign in to GitHub before submitting.',
        statusCode: 401,
      );
    }
    final repository = await api.getJson(
      '/repos/${config.repositoryOwner}/${config.repositoryName}',
      token,
    );
    if (repository['has_issues'] != true) {
      throw const GitHubApiException(
        'GitHub Issues are disabled for this repository.',
        statusCode: 410,
      );
    }
    final existing = await _findExisting(bundle, token);
    if (existing != null) return existing;
    onProgress?.call('Creating GitHub issue…', .82);
    final proposed = <String>{
      'bug',
      'platform-${Platform.operatingSystem}',
      bundle.draft.category == BugCategory.plugin
          ? 'plugins'
          : bundle.draft.category.name,
      'version-${bundle.diagnostics['hardwaremonVersion']}',
      'severity-${bundle.draft.severity.name}',
    };
    final available = await _getLabels(token);
    final labels = proposed
        .where((label) => available.contains(label.toLowerCase()))
        .toList();
    final user = await auth.getAuthenticatedUser();
    final response = await api.client
        .post(
          api.apiUri(
            '/repos/${config.repositoryOwner}/${config.repositoryName}/issues',
          ),
          headers: api.headers(token)..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'title': _issueTitle(bundle),
            'body': bundle.markdown,
            'labels': labels,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = api.parseObject(response);
    return BugReportSubmissionResult(
      issueNumber: body['number'] as int,
      issueUrl: Uri.parse(body['html_url'] as String),
      issueApiUrl: Uri.parse(body['url'] as String),
      createdAt: DateTime.parse(body['created_at'] as String),
      reportId: bundle.id,
      authenticatedLogin: user.login,
    );
  }

  Future<Set<String>> _getLabels(String token) async {
    if (_labelsFetchedAt != null &&
        DateTime.now().difference(_labelsFetchedAt!) <
            const Duration(minutes: 10)) {
      return _labels;
    }
    final response = await api.client
        .get(
          api.apiUri(
            '/repos/${config.repositoryOwner}/${config.repositoryName}/labels',
            {'per_page': '100'},
          ),
          headers: api.headers(token),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      api.parseObject(response);
    }
    _labels = (jsonDecode(response.body) as List)
        .map((item) => (item as Map)['name'].toString().toLowerCase())
        .toSet();
    _labelsFetchedAt = DateTime.now();
    return _labels;
  }

  Future<BugReportSubmissionResult?> _findExisting(
    BugReportBundle bundle,
    String token,
  ) async {
    final response = await api.client
        .get(
          api.apiUri(
            '/repos/${config.repositoryOwner}/${config.repositoryName}/issues',
            {'state': 'all', 'per_page': '30'},
          ),
          headers: api.headers(token),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      api.parseObject(response);
    }
    for (final raw in jsonDecode(response.body) as List) {
      final issue = Map<String, dynamic>.from(raw as Map);
      if (issue['pull_request'] != null) continue;
      if (!(issue['body']?.toString().contains(bundle.id) ?? false)) continue;
      final user = await auth.getAuthenticatedUser();
      return BugReportSubmissionResult(
        issueNumber: issue['number'] as int,
        issueUrl: Uri.parse(issue['html_url'] as String),
        issueApiUrl: Uri.parse(issue['url'] as String),
        createdAt: DateTime.parse(issue['created_at'] as String),
        reportId: bundle.id,
        authenticatedLogin: user.login,
      );
    }
    return null;
  }

  String _issueTitle(BugReportBundle bundle) {
    final platform = Platform.operatingSystem == 'macos'
        ? 'macOS'
        : Platform.operatingSystem[0].toUpperCase() +
              Platform.operatingSystem.substring(1);
    var title = bundle.draft.title.trim().replaceAll(RegExp(r'\s+'), ' ');
    final prefix = bundle.draft.category == BugCategory.crash
        ? '[Crash][$platform]'
        : '[$platform]';
    if (!title.toLowerCase().startsWith(prefix.toLowerCase())) {
      title = '$prefix $title';
    }
    return title.length > 240 ? title.substring(0, 240) : title;
  }
}

class BugReportService implements IBugReportService {
  BugReportService({
    required this.provider,
    DiagnosticsCollector? diagnosticsCollector,
    LogCollector? logCollector,
    BugReportBuilder? builder,
    ReportCompressor? compressor,
    PendingReportManager? pendingReports,
    ReportRedactor? redactor,
  }) : diagnosticsCollector = diagnosticsCollector ?? DiagnosticsCollector(),
       logCollector = logCollector ?? const LogCollector(),
       builder = builder ?? BugReportBuilder(),
       compressor = compressor ?? const ReportCompressor(),
       pendingReports = pendingReports ?? PendingReportManager(),
       redactor = redactor ?? ReportRedactor();

  final IBugReportProvider provider;
  final DiagnosticsCollector diagnosticsCollector;
  final LogCollector logCollector;
  final BugReportBuilder builder;
  final ReportCompressor compressor;
  final PendingReportManager pendingReports;
  final ReportRedactor redactor;

  @override
  Future<BugReportBundle> prepare(
    BugReportDraft draft, {
    ReportProgress? onProgress,
  }) async {
    final now = DateTime.now().toUtc();
    final random = Random.secure()
        .nextInt(0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    final id =
        'HM-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
    onProgress?.call('Preparing diagnostics…', .08);
    final diagnostics = draft.sections.contains(DiagnosticSection.diagnostics)
        ? await diagnosticsCollector.collect(draft.sections)
        : <String, Object?>{};
    if (draft.crashData != null &&
        draft.sections.contains(DiagnosticSection.crashData)) {
      diagnostics['crash'] = jsonDecode(draft.crashData!);
    }
    final redactedDiagnostics = Map<String, Object?>.from(
      redactor.redactJson(diagnostics) as Map,
    );
    onProgress?.call('Collecting logs…', .28);
    final collectedLogs = draft.sections.contains(DiagnosticSection.logs)
        ? await logCollector.collect()
        : <String, String>{};
    final logs = collectedLogs.map(
      (name, content) => MapEntry(name, redactor.redact(content)),
    );
    redactedDiagnostics['reportId'] = id;
    final safeDraft = BugReportDraft(
      title: redactor.redact(draft.title),
      category: draft.category,
      description: redactor.redact(draft.description),
      expectedBehaviour: redactor.redact(draft.expectedBehaviour),
      actualBehaviour: redactor.redact(draft.actualBehaviour),
      steps: draft.steps.map(redactor.redact).toList(),
      severity: draft.severity,
      sections: draft.sections,
      screenshotPaths: draft.screenshotPaths,
      crashData: draft.crashData == null
          ? null
          : redactor.redact(draft.crashData!),
    );
    final root = await pendingReports.root;
    final directory = Directory('${root.path}${Platform.pathSeparator}$id');
    await directory.create(recursive: true);
    final markdown = builder.markdown(safeDraft, redactedDiagnostics);
    await File(
      '${directory.path}${Platform.pathSeparator}report.md',
    ).writeAsString(markdown);
    await File(
      '${directory.path}${Platform.pathSeparator}draft.json',
    ).writeAsString(safeDraft.encode());
    await File(
      '${directory.path}${Platform.pathSeparator}diagnostics.json',
    ).writeAsString(
      const JsonEncoder.withIndent('  ').convert(redactedDiagnostics),
    );
    if (draft.crashData != null &&
        draft.sections.contains(DiagnosticSection.crashData)) {
      await File(
        '${directory.path}${Platform.pathSeparator}crash.txt',
      ).writeAsString(safeDraft.crashData!);
    }
    final logsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}logs',
    );
    if (logs.isNotEmpty) await logsDirectory.create();
    for (final entry in logs.entries) {
      final safeName = entry.key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      await File(
        '${logsDirectory.path}${Platform.pathSeparator}$safeName',
      ).writeAsString(entry.value);
    }
    final screenshotsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}screenshots',
    );
    for (final path in draft.screenshotPaths) {
      final source = File(path);
      if (!await source.exists()) continue;
      if (!await screenshotsDirectory.exists()) {
        await screenshotsDirectory.create();
      }
      await source.copy(
        '${screenshotsDirectory.path}${Platform.pathSeparator}${source.uri.pathSegments.last}',
      );
    }
    onProgress?.call('Compressing report…', .58);
    final archivePath =
        '${directory.path}${Platform.pathSeparator}hardwaremon-report-$id.zip';
    await compressor.compress(directory.path, archivePath);
    final bundle = BugReportBundle(
      id: id,
      createdAt: DateTime.now().toUtc(),
      draft: safeDraft,
      diagnostics: redactedDiagnostics,
      logs: logs,
      markdown: markdown,
      directoryPath: directory.path,
      archivePath: archivePath,
    );
    await pendingReports.save(
      PendingBugReport(
        id: id,
        title: draft.title,
        createdAt: bundle.createdAt,
        archivePath: archivePath,
        directoryPath: directory.path,
        state: PendingReportState.queued,
      ),
    );
    return bundle;
  }

  @override
  Future<BugReportSubmissionResult> submit(
    BugReportBundle bundle, {
    ReportProgress? onProgress,
  }) async {
    final existingReports = await pendingReports.list();
    final existing = existingReports
        .where((item) => item.id == bundle.id)
        .firstOrNull;
    final attemptCount = (existing?.attemptCount ?? 0) + 1;
    final attemptedAt = DateTime.now().toUtc();
    try {
      final result = await provider.submit(bundle, onProgress: onProgress);
      await pendingReports.save(
        PendingBugReport(
          id: bundle.id,
          title: bundle.draft.title,
          createdAt: bundle.createdAt,
          archivePath: bundle.archivePath,
          directoryPath: bundle.directoryPath,
          state: PendingReportState.sent,
          issueUrl: result.issueUrl.toString(),
          lastAttemptAt: attemptedAt,
          attemptCount: attemptCount,
        ),
      );
      onProgress?.call('Done.', 1);
      return result;
    } catch (error) {
      await pendingReports.save(
        PendingBugReport(
          id: bundle.id,
          title: bundle.draft.title,
          createdAt: bundle.createdAt,
          archivePath: bundle.archivePath,
          directoryPath: bundle.directoryPath,
          state: PendingReportState.failed,
          lastError: error.toString(),
          lastAttemptAt: attemptedAt,
          attemptCount: attemptCount,
          failureCategory: error is GitHubApiException
              ? 'github-${error.statusCode ?? 'network'}'
              : 'unexpected',
        ),
      );
      rethrow;
    }
  }
}
