import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';
import 'monitoring_lens.dart';
import 'telemetry_insights.dart';

class SessionJournalEntry {
  final String id;
  final DateTime capturedAt;
  final int score;
  final String stateLabel;
  final String observation;
  final String bottleneck;
  final MonitoringLens lens;
  final int cpuUsage;
  final int ramUsage;
  final int gpuUsage;
  final int hottestTemperature;

  const SessionJournalEntry({
    required this.id,
    required this.capturedAt,
    required this.score,
    required this.stateLabel,
    required this.observation,
    required this.bottleneck,
    required this.lens,
    required this.cpuUsage,
    required this.ramUsage,
    required this.gpuUsage,
    required this.hottestTemperature,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'capturedAt': capturedAt.toIso8601String(),
    'score': score,
    'stateLabel': stateLabel,
    'observation': observation,
    'bottleneck': bottleneck,
    'lens': lens.name,
    'cpuUsage': cpuUsage,
    'ramUsage': ramUsage,
    'gpuUsage': gpuUsage,
    'hottestTemperature': hottestTemperature,
  };

  factory SessionJournalEntry.fromJson(Map<String, dynamic> json) {
    return SessionJournalEntry(
      id: json['id'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      score: (json['score'] as num).round(),
      stateLabel: json['stateLabel'] as String,
      observation: json['observation'] as String,
      bottleneck: json['bottleneck'] as String,
      lens: MonitoringLens.values.firstWhere(
        (candidate) => candidate.name == json['lens'],
        orElse: () => MonitoringLens.balanced,
      ),
      cpuUsage: (json['cpuUsage'] as num).round(),
      ramUsage: (json['ramUsage'] as num).round(),
      gpuUsage: (json['gpuUsage'] as num).round(),
      hottestTemperature: (json['hottestTemperature'] as num).round(),
    );
  }

  String get report =>
      '''
HardwareMon session snapshot
Captured: ${capturedAt.toLocal().toIso8601String()}
Monitoring lens: ${lens.label}
Health: $score/100 · $stateLabel
Observation: $observation
Bottleneck: $bottleneck
CPU: $cpuUsage%
Memory: $ramUsage%
GPU: $gpuUsage%
Hottest sensor: ${hottestTemperature <= 0 ? 'Unavailable' : '$hottestTemperature°C'}
''';
}

class SessionJournal extends ChangeNotifier {
  static const _key = 'sessionJournalEntriesV1';
  static const maxEntries = 20;

  final SettingsService _settingsService;
  List<SessionJournalEntry> entries = const [];

  SessionJournal({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  Future<void> load() async {
    final raw = await _settingsService.getString(_key, '[]');
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      entries = decoded
          .whereType<Map<String, dynamic>>()
          .map(SessionJournalEntry.fromJson)
          .take(maxEntries)
          .toList(growable: false);
    } catch (_) {
      entries = const [];
    }
    notifyListeners();
  }

  Future<SessionJournalEntry> capture({
    required SystemHealthProfile profile,
    required MonitoringLens lens,
    required int cpuUsage,
    required int ramUsage,
    required int gpuUsage,
    required int cpuTemperature,
    required int gpuTemperature,
  }) async {
    final now = DateTime.now();
    final entry = SessionJournalEntry(
      id: now.microsecondsSinceEpoch.toString(),
      capturedAt: now,
      score: profile.overallScore,
      stateLabel: profile.stateLabel,
      observation: profile.observation,
      bottleneck: profile.bottleneck,
      lens: lens,
      cpuUsage: cpuUsage,
      ramUsage: ramUsage,
      gpuUsage: gpuUsage,
      hottestTemperature: cpuTemperature > gpuTemperature
          ? cpuTemperature
          : gpuTemperature,
    );
    entries = [entry, ...entries].take(maxEntries).toList(growable: false);
    notifyListeners();
    await _persist();
    return entry;
  }

  Future<void> remove(String id) async {
    entries = entries.where((entry) => entry.id != id).toList(growable: false);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    entries = const [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return _settingsService.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
