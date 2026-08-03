import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/privacy_notice_service.dart';

class StartupPrivacyNotice {
  static bool _showing = false;
  static const privacyPolicyUrl =
      'https://github.com/louisboii747/HardwareMon/blob/main/PRIVACY.md';

  static Future<bool> showIfRequired(
    BuildContext context, {
    PrivacyNoticeService? service,
  }) async {
    final notices = service ?? PrivacyNoticeService();
    if (_showing || !await notices.shouldShow() || !context.mounted) {
      return false;
    }
    _showing = true;
    try {
      final accepted = await showDetails(context, requireAcknowledgement: true);
      if (accepted && context.mounted) await notices.acknowledge();
      return accepted;
    } finally {
      _showing = false;
    }
  }

  static Future<bool> showDetails(
    BuildContext context, {
    bool requireAcknowledgement = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: !requireAcknowledgement,
          builder: (_) =>
              _PrivacySummaryDialog(required: requireAcknowledgement),
        ) ??
        false;
  }
}

class _PrivacySummaryDialog extends StatelessWidget {
  const _PrivacySummaryDialog({required this.required});
  final bool required;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.shield_outlined, semanticLabel: 'Privacy'),
    title: const Text('Privacy & Data'),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * .68,
      ),
      child: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HardwareMon processes system telemetry locally and gives you control over anything that leaves this device.',
            ),
            SizedBox(height: 18),
            _PrivacySection(
              title: 'Kept on this device',
              items: [
                'Live system telemetry and enabled historical telemetry',
                'Settings, benchmark results, diagnostics, and plugin metadata',
                'The LAN companion dashboard stays on your local network',
              ],
            ),
            SizedBox(height: 14),
            _PrivacySection(
              title: 'Features that use the network',
              items: [
                'Update and weather checks contact their named online services',
                'GitHub sign-in and issue submission contact GitHub only when you choose those actions',
                'A GitHub report sends only the Markdown you review and submit; locally exported files are not uploaded as attachments',
              ],
            ),
            SizedBox(height: 14),
            Text(
              'You can reopen this notice and review local-data controls in Settings. HardwareMon does not automatically upload telemetry to a cloud service.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(StartupPrivacyNotice.privacyPolicyUrl),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.open_in_new_rounded),
        label: const Text('Read full privacy policy'),
      ),
      if (!required)
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      FilledButton(
        autofocus: required,
        onPressed: () => Navigator.pop(context, true),
        child: Text(required ? 'Continue' : 'Done'),
      ),
    ],
  );
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    ),
  );
}
