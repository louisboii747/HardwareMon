import 'package:flutter/material.dart';

import 'update_service.dart';

class UpdatePromptService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final result = await UpdateService.checkForUpdates();
      if (!context.mounted) return;

      if (result['developmentBuild'] == true) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Development Build'),
            content: Text(
              'You are running a development build.\n\n'
              'Current: ${result['current']}\n'
              'Latest Stable: ${result['latest']}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (result['updateAvailable'] == true) {
        final install = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
              'Current Version: ${result['current']}\n'
              'Latest Version: ${result['latest']}\n\n'
              'Would you like to download the update now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Download'),
              ),
            ],
          ),
        );

        if (install == true) {
          final path = await UpdateService.downloadLatestRelease();
          if (!context.mounted) return;

          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Download Complete'),
              content: Text(
                'Update downloaded successfully.\n\nSaved to:\n$path',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Up To Date'),
          content: const Text('You already have the latest version installed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check for updates: $error')),
      );
    }
  }
}
