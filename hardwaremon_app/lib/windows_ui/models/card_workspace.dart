import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WorkspaceCardSize { compact, standard, wide, large }

extension WorkspaceCardSizeLabel on WorkspaceCardSize {
  String get label => switch (this) {
    WorkspaceCardSize.compact => 'Compact',
    WorkspaceCardSize.standard => 'Standard',
    WorkspaceCardSize.wide => 'Wide',
    WorkspaceCardSize.large => 'Large',
  };

  WorkspaceCardSize get next =>
      WorkspaceCardSize.values[(index + 1) % WorkspaceCardSize.values.length];
}

class WorkspaceCardState {
  final String id;
  final bool visible;
  final WorkspaceCardSize size;

  const WorkspaceCardState({
    required this.id,
    this.visible = true,
    this.size = WorkspaceCardSize.standard,
  });

  WorkspaceCardState copyWith({bool? visible, WorkspaceCardSize? size}) =>
      WorkspaceCardState(
        id: id,
        visible: visible ?? this.visible,
        size: size ?? this.size,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'visible': visible,
    'size': size.name,
  };

  factory WorkspaceCardState.fromJson(Map<String, dynamic> json) {
    final sizeName = json['size']?.toString();
    return WorkspaceCardState(
      id: json['id']?.toString() ?? '',
      visible: json['visible'] != false,
      size: WorkspaceCardSize.values.firstWhere(
        (value) => value.name == sizeName,
        orElse: () => WorkspaceCardSize.standard,
      ),
    );
  }
}

class SavedCardLayout {
  final String id;
  final String name;
  final DateTime createdAt;
  final Map<String, List<WorkspaceCardState>> pages;

  const SavedCardLayout({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.pages,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'pages': {
      for (final page in pages.entries)
        page.key: page.value.map((card) => card.toJson()).toList(),
    },
  };

  factory SavedCardLayout.fromJson(Map<String, dynamic> json) {
    final rawPages = Map<String, dynamic>.from(
      json['pages'] as Map? ?? const {},
    );
    return SavedCardLayout(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Saved layout',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      pages: {
        for (final page in rawPages.entries)
          page.key: (page.value as List? ?? const [])
              .whereType<Map>()
              .map(
                (card) => WorkspaceCardState.fromJson(
                  Map<String, dynamic>.from(card),
                ),
              )
              .where((card) => card.id.isNotEmpty)
              .toList(growable: false),
      },
    );
  }
}

class CardWorkspacePreferences extends ChangeNotifier {
  static const _stateKey = 'card_workspace_v1';
  static const _layoutsKey = 'card_workspace_saved_layouts_v1';

  final Map<String, List<WorkspaceCardState>> _pages = {};
  List<SavedCardLayout> _layouts = const [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<SavedCardLayout> get savedLayouts => List.unmodifiable(_layouts);
  Map<String, List<WorkspaceCardState>> get pages => {
    for (final entry in _pages.entries)
      entry.key: List.unmodifiable(entry.value),
  };

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _pages.clear();
    try {
      final decoded = jsonDecode(preferences.getString(_stateKey) ?? '{}');
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          _pages[entry.key.toString()] = (entry.value as List? ?? const [])
              .whereType<Map>()
              .map(
                (value) => WorkspaceCardState.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .where((card) => card.id.isNotEmpty)
              .toList();
        }
      }
    } on FormatException {
      _pages.clear();
    }
    try {
      final decoded = jsonDecode(preferences.getString(_layoutsKey) ?? '[]');
      _layouts = (decoded as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                SavedCardLayout.fromJson(Map<String, dynamic>.from(value)),
          )
          .where((layout) => layout.id.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      _layouts = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  List<WorkspaceCardState> resolve(String pageId, Iterable<String> defaults) {
    final defaultIds = defaults.toList(growable: false);
    final saved = _pages[pageId] ?? const [];
    final byId = {for (final card in saved) card.id: card};
    return [
      for (final card in saved)
        if (defaultIds.contains(card.id)) card,
      for (final id in defaultIds)
        if (!byId.containsKey(id)) WorkspaceCardState(id: id),
    ];
  }

  Future<void> reorder(
    String pageId,
    List<String> defaults,
    int oldIndex,
    int newIndex,
  ) async {
    final cards = resolve(pageId, defaults).toList();
    if (oldIndex < 0 ||
        oldIndex >= cards.length ||
        newIndex < 0 ||
        newIndex >= cards.length) {
      return;
    }
    final card = cards.removeAt(oldIndex);
    cards.insert(newIndex, card);
    _pages[pageId] = cards;
    await _save();
  }

  Future<void> setVisible(
    String pageId,
    List<String> defaults,
    String cardId,
    bool visible,
  ) async {
    final cards = resolve(pageId, defaults).toList();
    final index = cards.indexWhere((card) => card.id == cardId);
    if (index < 0) return;
    cards[index] = cards[index].copyWith(visible: visible);
    _pages[pageId] = cards;
    await _save();
  }

  Future<void> setSize(
    String pageId,
    List<String> defaults,
    String cardId,
    WorkspaceCardSize size,
  ) async {
    final cards = resolve(pageId, defaults).toList();
    final index = cards.indexWhere((card) => card.id == cardId);
    if (index < 0) return;
    cards[index] = cards[index].copyWith(size: size);
    _pages[pageId] = cards;
    await _save();
  }

  Future<void> resetPage(String pageId) async {
    _pages.remove(pageId);
    await _save();
  }

  Future<void> restoreCard(
    String pageId,
    List<String> defaults,
    String cardId,
  ) => setVisible(pageId, defaults, cardId, true);

  Future<void> saveLayout(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final layout = SavedCardLayout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
      pages: {
        for (final entry in _pages.entries) entry.key: List.of(entry.value),
      },
    );
    _layouts = [..._layouts, layout];
    await _saveLayouts();
  }

  Future<void> applyLayout(String id) async {
    final layout = _layouts.where((item) => item.id == id).firstOrNull;
    if (layout == null) return;
    _pages
      ..clear()
      ..addAll({
        for (final entry in layout.pages.entries)
          entry.key: List.of(entry.value),
      });
    await _save();
  }

  Future<void> deleteLayout(String id) async {
    _layouts = _layouts
        .where((layout) => layout.id != id)
        .toList(growable: false);
    await _saveLayouts();
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _stateKey,
      jsonEncode({
        for (final entry in _pages.entries)
          entry.key: entry.value.map((card) => card.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  Future<void> _saveLayouts() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _layoutsKey,
      jsonEncode(_layouts.map((layout) => layout.toJson()).toList()),
    );
    notifyListeners();
  }
}
