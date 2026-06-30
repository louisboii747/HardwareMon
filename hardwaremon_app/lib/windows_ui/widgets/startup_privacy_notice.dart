import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class StartupPrivacyNotice {
  static const summary =
      'Privacy-first: monitoring, diagnostics, and benchmarks stay on this device. '
      'HardwareMon does not currently upload telemetry or benchmark results; '
      'internet access is used for features such as update checks.';

  static void show(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        content: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.privacy_tip_outlined, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(summary, style: TextStyle(fontSize: 11, height: 1.4)),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => showDetails(context),
        ),
      ),
    );
  }

  static Future<void> showDetails(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const _PrivacySummaryDialog(),
    );
  }
}

class _PrivacySummaryDialog extends StatelessWidget {
  const _PrivacySummaryDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 22),
          SizedBox(width: 10),
          Expanded(child: Text('Privacy at a glance')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HardwareMon is designed to process system information locally.',
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 16),
              const _PrivacySection(
                title: 'Processed on this device',
                items: [
                  'CPU, GPU, memory, storage, operating-system, network, and process information',
                  'Live telemetry, diagnostics, benchmark results, and application settings',
                ],
              ),
              const SizedBox(height: 13),
              const _PrivacySection(
                title: 'Stored locally',
                items: [
                  'Settings, enabled telemetry history, benchmark history, and diagnostics you generate',
                  'Local files remain on this device unless you remove them',
                ],
              ),
              const SizedBox(height: 13),
              const _PrivacySection(
                title: 'Internet and future features',
                items: [
                  'Internet access may be used for update checks and downloads you request',
                  'Benchmark results are not currently uploaded',
                  'Any future anonymous benchmark sharing will be optional and require explicit consent',
                ],
              ),
              const SizedBox(height: 13),
              const _PrivacySection(
                title: 'Not intentionally shared for benchmarking',
                items: [
                  'Usernames, personal files, installed applications, serial numbers, MAC addresses, or IP addresses',
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'HardwareMon is open source, so its data handling can be reviewed publicly.',
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _PrivacySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
