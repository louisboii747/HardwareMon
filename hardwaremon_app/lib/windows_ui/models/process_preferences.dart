import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum ProcessSort { cpu, memory, activity, name, pid }

extension ProcessSortDetails on ProcessSort {
  String get label => switch (this) {
    ProcessSort.cpu => 'CPU',
    ProcessSort.memory => 'Memory',
    ProcessSort.activity => 'Activity',
    ProcessSort.name => 'Name',
    ProcessSort.pid => 'PID',
  };
}

enum ProcessQuickFilter { all, busy, rising, memory, watched }

extension ProcessQuickFilterDetails on ProcessQuickFilter {
  String get label => switch (this) {
    ProcessQuickFilter.all => 'All',
    ProcessQuickFilter.busy => 'Busy',
    ProcessQuickFilter.rising => 'Rising',
    ProcessQuickFilter.memory => 'Memory',
    ProcessQuickFilter.watched => 'Watched',
  };

  String get description => switch (this) {
    ProcessQuickFilter.all => 'Every process matching the search',
    ProcessQuickFilter.busy => 'CPU or memory pressure worth checking',
    ProcessQuickFilter.rising => 'Processes changing since the last refresh',
    ProcessQuickFilter.memory => 'Processes using at least 512 MB',
    ProcessQuickFilter.watched => 'Processes pinned to your local watchlist',
  };
}

class ProcessPreferences extends ChangeNotifier {
  static const _hideSystemProcessesKey = 'processHideSystemProcesses';
  static const _sortKey = 'processSort';
  static const _quickFilterKey = 'processQuickFilter';
  static const _autoRefreshKey = 'processAutoRefresh';
  static const _compactDensityKey = 'processCompactDensity';
  static const _watchedNamesKey = 'processWatchedNames';

  final SettingsService _settingsService;

  ProcessPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  bool hideSystemProcesses = true;
  bool autoRefresh = true;
  bool compactDensity = false;
  ProcessSort sort = ProcessSort.cpu;
  ProcessQuickFilter quickFilter = ProcessQuickFilter.all;
  Set<String> watchedProcessNames = {};

  Future<void> load() async {
    hideSystemProcesses = await _settingsService.getBool(
      _hideSystemProcessesKey,
      true,
    );
    autoRefresh = await _settingsService.getBool(_autoRefreshKey, true);
    compactDensity = await _settingsService.getBool(_compactDensityKey, false);

    final storedSort = await _settingsService.getString(
      _sortKey,
      ProcessSort.cpu.name,
    );
    sort = ProcessSort.values.firstWhere(
      (value) => value.name == storedSort,
      orElse: () => ProcessSort.cpu,
    );

    final storedFilter = await _settingsService.getString(
      _quickFilterKey,
      ProcessQuickFilter.all.name,
    );
    quickFilter = ProcessQuickFilter.values.firstWhere(
      (value) => value.name == storedFilter,
      orElse: () => ProcessQuickFilter.all,
    );

    watchedProcessNames = _decodeWatchedNames(
      await _settingsService.getString(_watchedNamesKey, '[]'),
    );
    notifyListeners();
  }

  Future<void> setHideSystemProcesses(bool value) async {
    hideSystemProcesses = value;
    notifyListeners();
    await _settingsService.setBool(_hideSystemProcessesKey, value);
  }

  Future<void> setAutoRefresh(bool value) async {
    autoRefresh = value;
    notifyListeners();
    await _settingsService.setBool(_autoRefreshKey, value);
  }

  Future<void> setCompactDensity(bool value) async {
    compactDensity = value;
    notifyListeners();
    await _settingsService.setBool(_compactDensityKey, value);
  }

  Future<void> setSort(ProcessSort value) async {
    sort = value;
    notifyListeners();
    await _settingsService.setString(_sortKey, value.name);
  }

  Future<void> setQuickFilter(ProcessQuickFilter value) async {
    quickFilter = value;
    notifyListeners();
    await _settingsService.setString(_quickFilterKey, value.name);
  }

  bool isWatched(String processName) {
    return watchedProcessNames.contains(normalizeName(processName));
  }

  Future<void> toggleWatched(String processName) async {
    final normalized = normalizeName(processName);
    if (normalized.isEmpty) return;

    if (!watchedProcessNames.add(normalized)) {
      watchedProcessNames.remove(normalized);
    }
    notifyListeners();
    await _persistWatchedNames();
  }

  Future<void> clearWatched() async {
    watchedProcessNames = {};
    notifyListeners();
    await _persistWatchedNames();
  }

  Future<void> _persistWatchedNames() async {
    final ordered = watchedProcessNames.toList()..sort();
    await _settingsService.setString(_watchedNamesKey, jsonEncode(ordered));
  }

  Set<String> _decodeWatchedNames(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return {};
      return decoded
          .whereType<String>()
          .map(normalizeName)
          .where((name) => name.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static String normalizeName(String processName) {
    return processName.trim().toLowerCase();
  }
}
