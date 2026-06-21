import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum DashboardWorkspace { overview, workload, thermals, power }

enum DashboardCardSize { compact, comfortable, expanded }

extension DashboardCardSizeDetails on DashboardCardSize {
  String get label => switch (this) {
    DashboardCardSize.compact => 'Compact',
    DashboardCardSize.comfortable => 'Comfortable',
    DashboardCardSize.expanded => 'Expanded',
  };

  double get height => switch (this) {
    DashboardCardSize.compact => 190,
    DashboardCardSize.comfortable => 240,
    DashboardCardSize.expanded => 310,
  };
}

enum DashboardMetricId {
  cpuUsage,
  memory,
  gpuUsage,
  cpuTemperature,
  gpuTemperature,
  cpuPower,
  gpuPower,
}

extension DashboardMetricDetails on DashboardMetricId {
  String get label => switch (this) {
    DashboardMetricId.cpuUsage => 'CPU Usage',
    DashboardMetricId.memory => 'Memory',
    DashboardMetricId.gpuUsage => 'GPU Usage',
    DashboardMetricId.cpuTemperature => 'CPU Temperature',
    DashboardMetricId.gpuTemperature => 'GPU Temperature',
    DashboardMetricId.cpuPower => 'CPU Power',
    DashboardMetricId.gpuPower => 'GPU Power',
  };
}

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
  static const _cardOrderKey = 'dashboardCardOrder';
  static const _hiddenCardsKey = 'dashboardHiddenCards';
  static const _cardSizeKey = 'dashboardCardSize';

  final SettingsService _settingsService;

  DashboardPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  DashboardWorkspace workspace = DashboardWorkspace.overview;
  List<DashboardMetricId> cardOrder = List.of(DashboardMetricId.values);
  Set<DashboardMetricId> hiddenCards = {};
  DashboardCardSize cardSize = DashboardCardSize.comfortable;

  Future<void> load() async {
    final stored = await _settingsService.getString(
      _workspaceKey,
      DashboardWorkspace.overview.name,
    );
    workspace = DashboardWorkspace.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => DashboardWorkspace.overview,
    );
    cardOrder = _decodeMetrics(
      await _settingsService.getString(
        _cardOrderKey,
        DashboardMetricId.values.map((value) => value.name).join(','),
      ),
      appendMissing: true,
    );
    hiddenCards = _decodeMetrics(
      await _settingsService.getString(_hiddenCardsKey, ''),
    ).toSet();
    final storedSize = await _settingsService.getString(
      _cardSizeKey,
      DashboardCardSize.comfortable.name,
    );
    cardSize = DashboardCardSize.values.firstWhere(
      (value) => value.name == storedSize,
      orElse: () => DashboardCardSize.comfortable,
    );
    notifyListeners();
  }

  Future<void> setWorkspace(DashboardWorkspace value) async {
    if (workspace == value) return;
    workspace = value;
    notifyListeners();
    await _settingsService.setString(_workspaceKey, value.name);
  }

  Future<void> reorderCard(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= cardOrder.length) return;
    if (newIndex > oldIndex) newIndex--;
    final updated = List<DashboardMetricId>.of(cardOrder);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex.clamp(0, updated.length), item);
    cardOrder = updated;
    notifyListeners();
    await _persistLayout();
  }

  Future<void> setCardVisible(DashboardMetricId id, bool visible) async {
    if (visible) {
      hiddenCards.remove(id);
    } else {
      hiddenCards.add(id);
    }
    notifyListeners();
    await _persistLayout();
  }

  Future<void> setCardSize(DashboardCardSize value) async {
    cardSize = value;
    notifyListeners();
    await _settingsService.setString(_cardSizeKey, value.name);
  }

  List<DashboardMetricId> orderedVisible(Iterable<DashboardMetricId> ids) {
    final available = ids.toSet();
    return cardOrder
        .where((id) => available.contains(id) && !hiddenCards.contains(id))
        .toList(growable: false);
  }

  Future<void> applySnapshot({
    required List<DashboardMetricId> order,
    required Set<DashboardMetricId> hidden,
    required DashboardCardSize size,
    DashboardWorkspace? selectedWorkspace,
  }) async {
    cardOrder = [
      ...order.where(DashboardMetricId.values.contains),
      ...DashboardMetricId.values.where((id) => !order.contains(id)),
    ];
    hiddenCards = hidden.where(DashboardMetricId.values.contains).toSet();
    cardSize = size;
    workspace = selectedWorkspace ?? workspace;
    notifyListeners();
    await Future.wait([
      _persistLayout(),
      _settingsService.setString(_cardSizeKey, cardSize.name),
      _settingsService.setString(_workspaceKey, workspace.name),
    ]);
  }

  Future<void> resetDefaults() async {
    workspace = DashboardWorkspace.overview;
    cardOrder = List.of(DashboardMetricId.values);
    hiddenCards = {};
    cardSize = DashboardCardSize.comfortable;
    notifyListeners();
    await Future.wait([
      _settingsService.setString(_workspaceKey, workspace.name),
      _persistLayout(),
      _settingsService.setString(_cardSizeKey, cardSize.name),
    ]);
  }

  Future<void> _persistLayout() {
    return Future.wait([
      _settingsService.setString(
        _cardOrderKey,
        cardOrder.map((value) => value.name).join(','),
      ),
      _settingsService.setString(
        _hiddenCardsKey,
        hiddenCards.map((value) => value.name).join(','),
      ),
    ]);
  }

  List<DashboardMetricId> _decodeMetrics(
    String value, {
    bool appendMissing = false,
  }) {
    final parsed = <DashboardMetricId>[];
    for (final name in value.split(',').where((item) => item.isNotEmpty)) {
      for (final candidate in DashboardMetricId.values) {
        if (candidate.name == name && !parsed.contains(candidate)) {
          parsed.add(candidate);
          break;
        }
      }
    }
    if (appendMissing) {
      parsed.addAll(
        DashboardMetricId.values.where((item) => !parsed.contains(item)),
      );
    }
    return parsed;
  }
}
