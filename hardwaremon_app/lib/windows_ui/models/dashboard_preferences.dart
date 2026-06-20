import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum DashboardWorkspace { overview, workload, thermals, power }

extension DashboardWorkspaceDetails on DashboardWorkspace {
  String get label => switch (this) {
    DashboardWorkspace.overview => 'Overview',
    DashboardWorkspace.workload => 'Workload',
    DashboardWorkspace.thermals => 'Thermals',
    DashboardWorkspace.power => 'Power',
  };

  String get description => switch (this) {
    DashboardWorkspace.overview => 'Everyday system health',
    DashboardWorkspace.workload => 'CPU, GPU, and memory pressure',
    DashboardWorkspace.thermals => 'Temperature and cooling headroom',
    DashboardWorkspace.power => 'Package and board power draw',
  };
}

class DashboardPreferences extends ChangeNotifier {
  static const _workspaceKey = 'dashboardWorkspace';

  final SettingsService _settingsService;

  DashboardPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  DashboardWorkspace workspace = DashboardWorkspace.overview;

  Future<void> load() async {
    final stored = await _settingsService.getString(
      _workspaceKey,
      DashboardWorkspace.overview.name,
    );
    workspace = DashboardWorkspace.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => DashboardWorkspace.overview,
    );
    notifyListeners();
  }

  Future<void> setWorkspace(DashboardWorkspace value) async {
    if (workspace == value) return;
    workspace = value;
    notifyListeners();
    await _settingsService.setString(_workspaceKey, value.name);
  }

  Future<void> resetDefaults() => setWorkspace(DashboardWorkspace.overview);
}
