import 'dart:io';
import 'dart:convert';

import 'package:flutter_gui/bug_reporting/bug_report_models.dart';
import 'package:flutter_gui/bug_reporting/bug_report_services.dart';
import 'package:flutter_gui/bug_reporting/github_auth.dart';
import 'package:flutter_gui/bug_reporting/report_redactor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('bug report drafts round-trip without losing consent choices', () {
    final draft = BugReportDraft(
      title: 'Telemetry stalls',
      category: BugCategory.telemetry,
      description: 'Charts stopped updating.',
      expectedBehaviour: 'Charts update.',
      actualBehaviour: 'Charts froze.',
      steps: const ['Open Performance', 'Wait ten seconds'],
      severity: BugSeverity.high,
      sections: const {DiagnosticSection.diagnostics, DiagnosticSection.logs},
      screenshotPaths: const ['capture.png'],
    );

    final decoded = BugReportDraft.fromJson(draft.toJson());
    expect(decoded.title, draft.title);
    expect(decoded.category, BugCategory.telemetry);
    expect(decoded.sections, draft.sections);
    expect(decoded.steps, draft.steps);
  });

  test('markdown builder includes report detail and system context', () {
    final markdown = BugReportBuilder().markdown(
      const BugReportDraft(
        title: 'Crash',
        category: BugCategory.crash,
        description: 'Closed while monitoring.',
        expectedBehaviour: 'Remain open.',
        actualBehaviour: 'Closed.',
        steps: ['Open app'],
        severity: BugSeverity.critical,
        sections: {DiagnosticSection.systemInformation},
      ),
      {
        'schemaVersion': 1,
        'hardwaremonVersion': '18.0.0',
        'buildNumber': '1',
        'releaseChannel': 'stable',
        'system': {'platform': 'windows', 'osVersion': '11'},
        'hardware': {'cpu_name': 'Example CPU', 'gpu_name': 'Example GPU'},
      },
    );

    expect(markdown, contains('## Steps to reproduce'));
    expect(markdown, contains('1. Open app'));
    expect(markdown, contains('Example CPU'));
    expect(markdown, contains('18.0.0'));
  });

  test('report compressor creates a readable non-empty zip', () async {
    final root = await Directory.systemTemp.createTemp('hardwaremon-report-');
    addTearDown(() => root.delete(recursive: true));
    await File(
      '${root.path}${Platform.pathSeparator}report.md',
    ).writeAsString('# Report');
    final target = '${root.path}${Platform.pathSeparator}report.zip';

    await const ReportCompressor().compress(root.path, target);

    expect(await File(target).exists(), isTrue);
    expect(await File(target).length(), greaterThan(0));
  });

  test(
    'redactor removes credentials, identity paths and network identifiers',
    () {
      final redactor = ReportRedactor(
        environment: {
          'HOME': '/home/alice',
          'GITHUB_TOKEN': 'ghp_abcdefghijklmnopqrstuvwxyz1234',
        },
      );
      final result = redactor.redact(
        'Authorization: Bearer secretvalue123456 /home/alice/a.log alice@example.com 203.0.113.4 00:11:22:33:44:55',
      );
      expect(result, isNot(contains('secretvalue')));
      expect(result, isNot(contains('alice')));
      expect(result, contains('<TOKEN_REDACTED>'));
      expect(result, contains('<HOME>'));
      expect(result, contains('<EMAIL>'));
      expect(result, contains('<IP_ADDRESS>'));
      expect(result, contains('<MAC_ADDRESS>'));
    },
  );

  test('device authorization parses expiry and polling interval', () {
    final now = DateTime.utc(2026, 8, 2);
    final value = GitHubDeviceAuthorization.fromJson({
      'device_code': 'device',
      'user_code': 'ABCD-EFGH',
      'verification_uri': 'https://github.com/login/device',
      'expires_in': 900,
      'interval': 7,
    }, now);
    expect(value.userCode, 'ABCD-EFGH');
    expect(value.interval, const Duration(seconds: 7));
    expect(value.expiresAt, now.add(const Duration(minutes: 15)));
  });

  test(
    'GitHub provider validates repository, filters labels, and creates issue',
    () async {
      late http.Request issueRequest;
      final client = MockClient((request) async {
        if (request.url.path == '/user') {
          return http.Response(jsonEncode({'login': 'reporter'}), 200);
        }
        if (request.url.path == '/repos/louisboii747/HardwareMon') {
          return http.Response(jsonEncode({'has_issues': true}), 200);
        }
        if (request.url.path.endsWith('/labels')) {
          return http.Response(
            jsonEncode([
              {'name': 'bug'},
              {'name': 'platform-windows'},
            ]),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/issues')) {
          return http.Response('[]', 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/issues')) {
          issueRequest = request;
          return http.Response(
            jsonEncode({
              'number': 123,
              'html_url':
                  'https://github.com/louisboii747/HardwareMon/issues/123',
              'url':
                  'https://api.github.com/repos/louisboii747/HardwareMon/issues/123',
              'created_at': '2026-08-02T12:00:00Z',
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      });
      final config = const GitHubBugReportingConfig(
        clientId: 'public-client-id',
        repositoryOwner: 'louisboii747',
        repositoryName: 'HardwareMon',
      );
      final api = GitHubApiClient(config: config, client: client);
      final store = _MemoryTokenStore('user-token');
      final auth = GitHubDeviceFlowAuthService(
        config: config,
        api: api,
        tokenStore: store,
      );
      final provider = GitHubBugProvider(config: config, auth: auth, api: api);
      final result = await provider.submit(
        BugReportBundle(
          id: 'HM-20260802-4F7A92C1',
          createdAt: DateTime.utc(2026, 8, 2),
          draft: const BugReportDraft(
            title: 'GPU temperature disappears',
            category: BugCategory.telemetry,
            description: 'Description',
            expectedBehaviour: '',
            actualBehaviour: '',
            steps: [],
            severity: BugSeverity.high,
            sections: {},
          ),
          diagnostics: const {'hardwaremonVersion': '18.0.0'},
          logs: const {},
          markdown: 'Report ID: HM-20260802-4F7A92C1',
          directoryPath: '.',
          archivePath: 'report.zip',
        ),
      );
      final payload = jsonDecode(issueRequest.body) as Map<String, dynamic>;
      expect(issueRequest.headers['authorization'], 'Bearer user-token');
      expect(issueRequest.headers['user-agent'], 'HardwareMon-Bug-Reporter');
      expect(payload['title'], contains('GPU temperature disappears'));
      expect(payload['labels'], contains('bug'));
      expect(payload['labels'], isNot(contains('telemetry')));
      expect(result.issueNumber, 123);
      expect(result.authenticatedLogin, 'reporter');
    },
  );
}

class _MemoryTokenStore implements SecureTokenStore {
  _MemoryTokenStore(this.value);
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
}
