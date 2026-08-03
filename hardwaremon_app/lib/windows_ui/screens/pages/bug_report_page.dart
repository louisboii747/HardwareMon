import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../bug_reporting/bug_report_models.dart';
import '../../../bug_reporting/bug_report_services.dart';
import '../../../bug_reporting/github_auth.dart';

class BugReportPage extends StatefulWidget {
  const BugReportPage({super.key, this.crashData, this.onShowPending});
  final String? crashData;
  final VoidCallback? onShowPending;

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _captureKey = GlobalKey();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  final _steps = <TextEditingController>[TextEditingController()];
  final _screenshots = <String>[];
  final _sections = <DiagnosticSection>{
    DiagnosticSection.diagnostics,
    DiagnosticSection.logs,
    DiagnosticSection.systemInformation,
    DiagnosticSection.applicationSettings,
    DiagnosticSection.hardwareInformation,
    DiagnosticSection.recentTelemetry,
  };
  BugCategory _category = BugCategory.other;
  BugSeverity _severity = BugSeverity.medium;
  bool _busy = false;
  String _progressMessage = '';
  double _progress = 0;
  late final GitHubBugReportingConfig _githubConfig;
  late final GitHubApiClient _githubApi;
  late final GitHubDeviceFlowAuthService _githubAuth;
  late final BugReportService _service;
  late Future<GitHubReportingCapability> _githubCapability;

  @override
  void initState() {
    super.initState();
    _githubConfig = GitHubBugReportingConfig.production();
    _githubApi = GitHubApiClient(config: _githubConfig);
    _githubAuth = GitHubDeviceFlowAuthService(
      config: _githubConfig,
      api: _githubApi,
    );
    _service = BugReportService(
      provider: GitHubBugProvider(
        config: _githubConfig,
        auth: _githubAuth,
        api: _githubApi,
      ),
    );
    _githubCapability = _githubAuth.getCapability();
    if (widget.crashData != null) {
      _category = BugCategory.crash;
      _severity = BugSeverity.high;
      _sections.add(DiagnosticSection.crashData);
      _title.text = 'HardwareMon unexpectedly crashed';
      _description.text = 'HardwareMon closed unexpectedly.';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _expected.dispose();
    _actual.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  BugReportDraft _draft() => BugReportDraft(
    title: _title.text.trim(),
    category: _category,
    description: _description.text.trim(),
    expectedBehaviour: _expected.text.trim(),
    actualBehaviour: _actual.text.trim(),
    steps: _steps.map((item) => item.text.trim()).toList(),
    severity: _severity,
    sections: Set.of(_sections),
    screenshotPaths: List.of(_screenshots),
    crashData: widget.crashData,
  );

  Future<void> _browseScreenshots() async {
    const group = XTypeGroup(
      label: 'Screenshots',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final files = await openFiles(acceptedTypeGroups: const [group]);
    if (!mounted) return;
    setState(() {
      for (final file in files) {
        if (!_screenshots.contains(file.path)) _screenshots.add(file.path);
      }
      if (_screenshots.isNotEmpty) _sections.add(DiagnosticSection.screenshots);
    });
  }

  Future<void> _captureWindow() async {
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final path = await const ScreenshotCollector().saveCaptured(
        data.buffer.asUint8List(),
      );
      if (mounted) {
        setState(() {
          _screenshots.add(path);
          _sections.add(DiagnosticSection.screenshots);
        });
      }
    } catch (error) {
      if (mounted) _showMessage('Could not capture this window: $error');
    }
  }

  Future<bool> _showPreview(BugReportBundle bundle) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Diagnostics Preview'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HardwareMon only sends the information shown below.\n'
                      'Nothing is uploaded without your permission.\n'
                      'No personal files are collected.',
                    ),
                    const SizedBox(height: 16),
                    const Text('Exact Markdown that will be sent to GitHub:'),
                    const SizedBox(height: 8),
                    SelectableText(
                      bundle.markdown,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send Report'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<BugReportBundle?> _prepare() async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _busy = true);
    try {
      return await _service.prepare(
        _draft(),
        onProgress: (message, progress) {
          if (mounted) {
            setState(() {
              _progressMessage = message;
              _progress = progress;
            });
          }
        },
      );
    } catch (error) {
      if (mounted) _showMessage('The report could not be prepared: $error');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final bundle = await _prepare();
    if (bundle == null || !mounted) return;
    if (!await _showPreview(bundle) || !mounted) return;
    if (!_githubConfig.isConfigured) {
      _showMessage(_githubConfig.configurationMessage);
      return;
    }
    final authState = await _githubAuth.getAuthState();
    if (!mounted) return;
    if (authState.status != GitHubAuthStatus.signedIn) {
      final signedIn = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            GitHubDeviceFlowDialog(auth: _githubAuth, config: _githubConfig),
      );
      if (signedIn != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.submit(
        bundle,
        onProgress: (message, progress) {
          if (mounted) {
            setState(() {
              _progressMessage = message;
              _progress = progress;
            });
          }
        },
      );
      if (mounted) await _showSuccess(result, bundle);
    } catch (error) {
      if (mounted) {
        _showMessage('Report saved. It can be sent later.\n\n$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSuccess(
    BugReportSubmissionResult result,
    BugReportBundle bundle,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Issue #${result.issueNumber} was created successfully'),
      content: SizedBox(
        width: 620,
        child: Text(
          'Your description and selected text diagnostics were included.\n\n'
          'GitHub does not provide an Issues API for automatically uploading local binary files. '
          'Open the issue to add the ZIP or screenshots manually.\n\n'
          'Attachments: ${bundle.archivePath}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(
            ClipboardData(text: result.issueUrl.toString()),
          ),
          child: const Text('Copy issue link'),
        ),
        TextButton(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: result.reportId)),
          child: const Text('Copy report ID'),
        ),
        OutlinedButton(
          onPressed: () => _openPath(bundle.directoryPath),
          child: const Text('Open attachment folder'),
        ),
        FilledButton(
          onPressed: () =>
              launchUrl(result.issueUrl, mode: LaunchMode.externalApplication),
          child: const Text('Open GitHub issue'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  Future<void> _openPath(String path) async {
    if (Platform.isWindows) await Process.run('explorer.exe', [path]);
    if (Platform.isLinux) await Process.run('xdg-open', [path]);
    if (Platform.isMacOS) await Process.run('open', [path]);
  }

  Future<void> _save() async {
    final bundle = await _prepare();
    if (bundle == null || !mounted) return;
    final location = await getSaveLocation(
      suggestedName: 'hardwaremon-report-${bundle.id}.zip',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP archive', extensions: ['zip']),
      ],
    );
    if (location == null) return;
    await File(bundle.archivePath).copy(location.path);
    if (mounted) _showMessage('Report saved to:\n${location.path}');
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _captureKey,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            FutureBuilder<GitHubReportingCapability>(
              future: _githubCapability,
              builder: (context, snapshot) {
                final capability = snapshot.data;
                final loading = capability == null;
                final signedOut =
                    capability?.state ==
                    GitHubReportingAvailability.availableSignedOut;
                final ready =
                    capability?.state ==
                    GitHubReportingAvailability.signedInReady;
                return Card(
                  child: ListTile(
                    leading: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            ready
                                ? Icons.check_circle_outline
                                : Icons.cloud_outlined,
                          ),
                    title: Text(
                      loading
                          ? 'Checking GitHub reporting…'
                          : capability.message,
                    ),
                    subtitle: signedOut
                        ? const Text(
                            'You can compose and preview the report before signing in.',
                          )
                        : null,
                    trailing: loading || ready || signedOut
                        ? null
                        : TextButton(
                            onPressed: () => setState(
                              () => _githubCapability = _githubAuth
                                  .getCapability(),
                            ),
                            child: const Text('Retry availability check'),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bug_report_rounded, size: 58),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report a Bug',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Help improve HardwareMon by sending us information about the problem you experienced.',
                        ),
                      ],
                    ),
                  ),
                  if (widget.onShowPending != null)
                    TextButton.icon(
                      onPressed: widget.onShowPending,
                      icon: const Icon(Icons.schedule_send_rounded),
                      label: const Text('Pending Reports'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Issue title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an issue title.'
                  : null,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<BugCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: BugCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<BugSeverity>(
                    initialValue: _severity,
                    decoration: const InputDecoration(
                      labelText: 'Severity',
                      border: OutlineInputBorder(),
                    ),
                    items: BugSeverity.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _severity = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText:
                    'Tell us exactly what happened.\n\nWhat were you doing?\n\nCan you reproduce it?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe what happened.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _expected,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Expected behaviour',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _actual,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Actual behaviour',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Steps to reproduce',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text('${index + 1}.')),
                    Expanded(
                      child: TextField(
                        controller: _steps[index],
                        decoration: const InputDecoration(
                          hintText: 'Describe this step',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove step',
                      onPressed: _steps.length == 1
                          ? null
                          : () => setState(
                              () => _steps.removeAt(index).dispose(),
                            ),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _steps.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add step'),
              ),
            ),
            const Divider(height: 36),
            Text(
              'Include with this report',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'You can opt out of any section. Screenshots are off by default.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final section in DiagnosticSection.values)
                  if (section != DiagnosticSection.crashData ||
                      widget.crashData != null)
                    SizedBox(
                      width: 300,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _sections.contains(section),
                        title: Text(
                          'Include ${section.displayName.toLowerCase()}',
                        ),
                        onChanged: (value) => setState(
                          () => value == true
                              ? _sections.add(section)
                              : _sections.remove(section),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _captureWindow,
                  icon: const Icon(Icons.screenshot_rounded),
                  label: const Text('Capture current window'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _browseScreenshots,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Browse for screenshots'),
                ),
              ],
            ),
            if (_screenshots.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _screenshots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_screenshots[index]),
                          width: 150,
                          height: 105,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 150,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove image',
                          onPressed: () =>
                              setState(() => _screenshots.removeAt(index)),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'HardwareMon only sends the information shown in the preview. Nothing is uploaded without your permission. No personal files are collected.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 6),
              Text(_progressMessage, semanticsLabel: _progressMessage),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save Report'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Review & Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class PendingReportsPage extends StatefulWidget {
  const PendingReportsPage({super.key});
  @override
  State<PendingReportsPage> createState() => _PendingReportsPageState();
}

class CrashRecoveryGate extends StatefulWidget {
  const CrashRecoveryGate({super.key, required this.child});
  final Widget child;

  @override
  State<CrashRecoveryGate> createState() => _CrashRecoveryGateState();
}

class GitHubDeviceFlowDialog extends StatefulWidget {
  const GitHubDeviceFlowDialog({
    super.key,
    required this.auth,
    required this.config,
  });
  final GitHubDeviceFlowAuthService auth;
  final GitHubBugReportingConfig config;
  @override
  State<GitHubDeviceFlowDialog> createState() => _GitHubDeviceFlowDialogState();
}

class _GitHubDeviceFlowDialogState extends State<GitHubDeviceFlowDialog> {
  GitHubDeviceAuthorization? authorization;
  String? error;
  Timer? timer;
  Duration remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final value = await widget.auth.beginDeviceAuthorization();
      if (!mounted) return;
      setState(() {
        authorization = value;
        remaining = value.expiresAt.difference(DateTime.now());
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(
            () => remaining = value.expiresAt.difference(DateTime.now()),
          );
        }
      });
      await widget.auth.waitForAuthorization(value);
      if (mounted) Navigator.pop(context, true);
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.login_rounded, size: 44),
    title: const Text('Connect GitHub'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'HardwareMon will use your GitHub account only to create the issue you approve in ${widget.config.repositorySlug}.',
          ),
          const SizedBox(height: 18),
          if (authorization == null && error == null)
            const CircularProgressIndicator(),
          if (authorization != null) ...[
            Text('1. Open ${authorization!.verificationUri}'),
            const SizedBox(height: 8),
            const Text('2. Enter this code:'),
            const SizedBox(height: 8),
            SelectableText(
              authorization!.userCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: authorization!.userCode),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy code'),
                ),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    authorization!.verificationUri,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Open GitHub'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Waiting for authorization… ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')} remaining',
            ),
            const Text('Requested permission: public_repo'),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      if (error != null)
        TextButton(
          onPressed: () {
            setState(() => error = null);
            _start();
          },
          child: const Text('Retry'),
        ),
      TextButton(
        onPressed: () {
          widget.auth.cancelAuthorization();
          Navigator.pop(context, false);
        },
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _CrashRecoveryGateState extends State<CrashRecoveryGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final crash = await CrashCollector.consume();
    if (crash == null || !mounted) return;
    final send = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, size: 48),
        title: const Text('HardwareMon unexpectedly crashed'),
        content: const Text(
          'Sorry about that. Would you like to send a crash report to help improve HardwareMon?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Don't Send"),
          ),
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Crash Details'),
                content: SizedBox(
                  width: 700,
                  child: SingleChildScrollView(child: SelectableText(crash)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('View Details'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Report'),
          ),
        ],
      ),
    );
    if (send == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BugReportPage(crashData: crash),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PendingReportsPageState extends State<PendingReportsPage> {
  final _manager = PendingReportManager();
  late Future<List<PendingBugReport>> _reports = _manager.list();
  final Set<String> _retrying = {};

  void _refresh() => setState(() => _reports = _manager.list());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pending Reports')),
    body: FutureBuilder<List<PendingBugReport>>(
      future: _reports,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text('No saved reports.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final report = reports[index];
            return ListTile(
              leading: Icon(
                report.state == PendingReportState.sent
                    ? Icons.check_circle_outline
                    : Icons.schedule_send_rounded,
              ),
              title: Text(report.title),
              subtitle: Text(
                '${report.createdAt.toLocal()} • ${report.state.displayName}${report.lastError == null ? '' : '\n${report.lastError}'}',
              ),
              isThreeLine: report.lastError != null,
              trailing: Wrap(
                children: [
                  if (report.state != PendingReportState.sent)
                    IconButton(
                      tooltip: 'Retry',
                      onPressed: _retrying.contains(report.id)
                          ? null
                          : () => _retry(report),
                      icon: _retrying.contains(report.id)
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  IconButton(
                    tooltip: 'View files',
                    onPressed: () => _openDirectory(report.directoryPath),
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      await _manager.delete(report);
                      _refresh();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _openDirectory(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    }
  }

  Future<void> _retry(PendingBugReport report) async {
    setState(() => _retrying.add(report.id));
    try {
      final directory = Directory(report.directoryPath);
      final draft = BugReportDraft.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                await File(
                  '${directory.path}${Platform.pathSeparator}draft.json',
                ).readAsString(),
              )
              as Map,
        ),
      );
      final diagnostics = Map<String, Object?>.from(
        jsonDecode(
              await File(
                '${directory.path}${Platform.pathSeparator}diagnostics.json',
              ).readAsString(),
            )
            as Map,
      );
      final markdown = await File(
        '${directory.path}${Platform.pathSeparator}report.md',
      ).readAsString();
      final config = GitHubBugReportingConfig.production();
      final api = GitHubApiClient(config: config);
      final auth = GitHubDeviceFlowAuthService(config: config, api: api);
      if ((await auth.getAuthState()).status != GitHubAuthStatus.signedIn) {
        throw const GitHubApiException(
          'Open the report page and sign in to GitHub before retrying.',
        );
      }
      final service = BugReportService(
        provider: GitHubBugProvider(config: config, auth: auth, api: api),
      );
      await service.submit(
        BugReportBundle(
          id: report.id,
          createdAt: report.createdAt,
          draft: draft,
          diagnostics: diagnostics,
          logs: const {},
          markdown: markdown,
          directoryPath: report.directoryPath,
          archivePath: report.archivePath,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report remains queued: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retrying.remove(report.id));
        _refresh();
      }
    }
  }
}
