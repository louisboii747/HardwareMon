import 'package:flutter/material.dart';

import '../windows_ui/services/settings_service.dart';
import '../windows_ui/widgets/update_center.dart';
import 'update_service.dart';

class UpdatePromptService {
  static Future<void> checkForUpdates(BuildContext context) {
    return showUpdateCenter(context, checkImmediately: true);
  }

  static Future<void> showStartupResult(BuildContext context) {
    return showUpdateCenter(context, checkImmediately: false);
  }

  static Future<void> checkAutomatically(BuildContext context) async {
    final settingsService = SettingsService();
    final settings = await settingsService.loadSettings();
    if (!settings.autoUpdateChecks || !context.mounted) return;

    final lastCheckValue = await settingsService.getString(
      'lastAutomaticUpdateCheck',
      '',
    );
    final lastCheck = DateTime.tryParse(lastCheckValue);
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(hours: 24)) {
      return;
    }

    await settingsService.setString(
      'lastAutomaticUpdateCheck',
      DateTime.now().toIso8601String(),
    );
    final state = await UpdateService.instance.checkForUpdates();
    if (state.updateAvailable && context.mounted) {
      await showUpdateCenter(context, checkImmediately: false);
    }
  }
}
