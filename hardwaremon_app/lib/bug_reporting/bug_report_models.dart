import 'dart:convert';

enum BugCategory {
  crash,
  performance,
  ui,
  telemetry,
  plugin,
  installation,
  update,
  linux,
  windows,
  macos,
  android,
  notifications,
  benchmark,
  companion,
  settings,
  other,
}

enum BugSeverity { low, medium, high, critical }

enum DiagnosticSection {
  diagnostics,
  logs,
  systemInformation,
  applicationSettings,
  hardwareInformation,
  screenshots,
  recentTelemetry,
  crashData,
}

enum PendingReportState { queued, sending, sent, failed }

extension DisplayEnum on Enum {
  String get displayName {
    final value = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class BugReportDraft {
  const BugReportDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.expectedBehaviour,
    required this.actualBehaviour,
    required this.steps,
    required this.severity,
    required this.sections,
    this.screenshotPaths = const [],
    this.crashData,
  });

  final String title;
  final BugCategory category;
  final String description;
  final String expectedBehaviour;
  final String actualBehaviour;
  final List<String> steps;
  final BugSeverity severity;
  final Set<DiagnosticSection> sections;
  final List<String> screenshotPaths;
  final String? crashData;

  Map<String, Object?> toJson() => {
    'title': title,
    'category': category.name,
    'description': description,
    'expectedBehaviour': expectedBehaviour,
    'actualBehaviour': actualBehaviour,
    'steps': steps,
    'severity': severity.name,
    'sections': sections.map((item) => item.name).toList(),
    'screenshotPaths': screenshotPaths,
    'crashData': crashData,
  };

  factory BugReportDraft.fromJson(Map<String, dynamic> json) => BugReportDraft(
    title: json['title'] as String? ?? '',
    category: BugCategory.values.byName(json['category'] as String? ?? 'other'),
    description: json['description'] as String? ?? '',
    expectedBehaviour: json['expectedBehaviour'] as String? ?? '',
    actualBehaviour: json['actualBehaviour'] as String? ?? '',
    steps: List<String>.from(json['steps'] as List? ?? const []),
    severity: BugSeverity.values.byName(
      json['severity'] as String? ?? 'medium',
    ),
    sections: (json['sections'] as List? ?? const [])
        .map((item) => DiagnosticSection.values.byName(item.toString()))
        .toSet(),
    screenshotPaths: List<String>.from(
      json['screenshotPaths'] as List? ?? const [],
    ),
    crashData: json['crashData'] as String?,
  );

  String encode() => jsonEncode(toJson());
}

class BugReportBundle {
  const BugReportBundle({
    required this.id,
    required this.createdAt,
    required this.draft,
    required this.diagnostics,
    required this.logs,
    required this.markdown,
    required this.directoryPath,
    required this.archivePath,
  });

  final String id;
  final DateTime createdAt;
  final BugReportDraft draft;
  final Map<String, Object?> diagnostics;
  final Map<String, String> logs;
  final String markdown;
  final String directoryPath;
  final String archivePath;
}

class BugReportSubmissionResult {
  const BugReportSubmissionResult({
    required this.issueNumber,
    required this.issueUrl,
    required this.issueApiUrl,
    required this.createdAt,
    required this.reportId,
    this.authenticatedLogin,
  });
  final int issueNumber;
  final Uri issueUrl;
  final Uri issueApiUrl;
  final DateTime createdAt;
  final String reportId;
  final String? authenticatedLogin;
}

class PendingBugReport {
  const PendingBugReport({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.archivePath,
    required this.directoryPath,
    required this.state,
    this.lastError,
    this.issueUrl,
    this.lastAttemptAt,
    this.attemptCount = 0,
    this.failureCategory,
    this.targetProvider = 'github-issues',
    this.targetRepository,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String archivePath;
  final String directoryPath;
  final PendingReportState state;
  final String? lastError;
  final String? issueUrl;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final String? failureCategory;
  final String targetProvider;
  final String? targetRepository;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'archivePath': archivePath,
    'directoryPath': directoryPath,
    'state': state.name,
    'lastError': lastError,
    'issueUrl': issueUrl,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'attemptCount': attemptCount,
    'failureCategory': failureCategory,
    'targetProvider': targetProvider,
    'targetRepository': targetRepository,
  };

  factory PendingBugReport.fromJson(Map<String, dynamic> json) =>
      PendingBugReport(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        archivePath: json['archivePath'] as String,
        directoryPath: json['directoryPath'] as String,
        state: PendingReportState.values.byName(json['state'] as String),
        lastError: json['lastError'] as String?,
        issueUrl: json['issueUrl'] as String?,
        lastAttemptAt: json['lastAttemptAt'] == null
            ? null
            : DateTime.parse(json['lastAttemptAt'] as String),
        attemptCount: json['attemptCount'] as int? ?? 0,
        failureCategory: json['failureCategory'] as String?,
        targetProvider: json['targetProvider'] as String? ?? 'github-issues',
        targetRepository: json['targetRepository'] as String?,
      );

  PendingBugReport copyWith({
    PendingReportState? state,
    String? lastError,
    String? issueUrl,
    DateTime? lastAttemptAt,
    int? attemptCount,
    String? failureCategory,
  }) => PendingBugReport(
    id: id,
    title: title,
    createdAt: createdAt,
    archivePath: archivePath,
    directoryPath: directoryPath,
    state: state ?? this.state,
    lastError: lastError,
    issueUrl: issueUrl,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    attemptCount: attemptCount ?? this.attemptCount,
    failureCategory: failureCategory,
    targetProvider: targetProvider,
    targetRepository: targetRepository,
  );
}
