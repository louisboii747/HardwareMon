class GameMetadata {
  final String name;
  final List<String> executables;
  final String icon;
  final String? genre;
  final String? publisher;
  final String? steamAppId;

  const GameMetadata({
    required this.name,
    required this.executables,
    required this.icon,
    required this.genre,
    required this.publisher,
    required this.steamAppId,
  });

  factory GameMetadata.fromJson(Map<String, dynamic> json) {
    return GameMetadata(
      name: json['name']?.toString() ?? 'Unknown game',
      executables: (json['executables'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      icon: json['icon']?.toString() ?? 'gamepad',
      genre: _optionalString(json['genre']),
      publisher: _optionalString(json['publisher']),
      steamAppId: _optionalString(json['steam_app_id']),
    );
  }
}

class GamingProcess {
  final String gameName;
  final String executable;
  final int pid;
  final double? startedAt;
  final String? genre;
  final String? publisher;
  final String? steamAppId;

  const GamingProcess({
    required this.gameName,
    required this.executable,
    required this.pid,
    required this.startedAt,
    required this.genre,
    required this.publisher,
    required this.steamAppId,
  });

  factory GamingProcess.fromJson(Map<String, dynamic> json) {
    return GamingProcess(
      gameName: json['game_name']?.toString() ?? 'Unknown game',
      executable: json['executable']?.toString() ?? 'Unknown executable',
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      startedAt: (json['started_at'] as num?)?.toDouble(),
      genre: _optionalString(json['genre']),
      publisher: _optionalString(json['publisher']),
      steamAppId: _optionalString(json['steam_app_id']),
    );
  }
}

class GamingSample {
  final DateTime sampledAt;
  final double? cpuUsage;
  final double? gpuUsage;
  final double? ramUsage;
  final double? cpuTemperature;
  final double? gpuTemperature;
  final double? cpuClock;
  final double? gpuPower;
  final double? cpuPower;

  const GamingSample({
    required this.sampledAt,
    required this.cpuUsage,
    required this.gpuUsage,
    required this.ramUsage,
    required this.cpuTemperature,
    required this.gpuTemperature,
    required this.cpuClock,
    required this.gpuPower,
    required this.cpuPower,
  });

  factory GamingSample.fromJson(Map<String, dynamic> json) {
    return GamingSample(
      sampledAt: _parseDate(json['sampled_at']),
      cpuUsage: _optionalDouble(json['cpu_usage']),
      gpuUsage: _optionalDouble(json['gpu_usage']),
      ramUsage: _optionalDouble(json['ram_usage']),
      cpuTemperature: _optionalDouble(json['cpu_temperature']),
      gpuTemperature: _optionalDouble(json['gpu_temperature']),
      cpuClock: _optionalDouble(json['cpu_clock']),
      gpuPower: _optionalDouble(json['gpu_power']),
      cpuPower: _optionalDouble(json['cpu_power']),
    );
  }
}

class GamingSession {
  final String id;
  final String gameName;
  final String executable;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double durationSeconds;
  final String platform;
  final double? avgCpuUsage;
  final double? avgGpuUsage;
  final double? avgRamUsage;
  final double? avgCpuTemperature;
  final double? avgGpuTemperature;
  final double? peakCpuTemperature;
  final double? peakGpuTemperature;
  final double? peakRamUsage;
  final double? peakGpuUsage;
  final double? avgCpuClock;
  final double? avgGpuPower;
  final double? avgCpuPower;
  final double? maxCpuUsage;
  final double? maxGpuUsage;
  final int totalSamples;
  final String hardwaremonVersion;
  final String status;
  final GameMetadata? game;
  final List<GamingProcess> activeProcesses;
  final GamingSample? latestSample;

  const GamingSession({
    required this.id,
    required this.gameName,
    required this.executable,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.platform,
    required this.avgCpuUsage,
    required this.avgGpuUsage,
    required this.avgRamUsage,
    required this.avgCpuTemperature,
    required this.avgGpuTemperature,
    required this.peakCpuTemperature,
    required this.peakGpuTemperature,
    required this.peakRamUsage,
    required this.peakGpuUsage,
    required this.avgCpuClock,
    required this.avgGpuPower,
    required this.avgCpuPower,
    required this.maxCpuUsage,
    required this.maxGpuUsage,
    required this.totalSamples,
    required this.hardwaremonVersion,
    required this.status,
    required this.game,
    required this.activeProcesses,
    required this.latestSample,
  });

  bool get isActive => status == 'active' || endedAt == null;

  factory GamingSession.fromJson(Map<String, dynamic> json) {
    final gameJson = _mapOrNull(json['game']);
    final sampleJson = _mapOrNull(json['latest_sample']);
    return GamingSession(
      id: json['id']?.toString() ?? '',
      gameName: json['game_name']?.toString() ?? 'Unknown game',
      executable: json['executable']?.toString() ?? 'Unknown executable',
      startedAt: _parseDate(json['started_at']),
      endedAt: _parseOptionalDate(json['ended_at']),
      durationSeconds: _optionalDouble(json['duration_seconds']) ?? 0,
      platform: json['platform']?.toString() ?? 'Unknown platform',
      avgCpuUsage: _optionalDouble(json['avg_cpu_usage']),
      avgGpuUsage: _optionalDouble(json['avg_gpu_usage']),
      avgRamUsage: _optionalDouble(json['avg_ram_usage']),
      avgCpuTemperature: _optionalDouble(json['avg_cpu_temperature']),
      avgGpuTemperature: _optionalDouble(json['avg_gpu_temperature']),
      peakCpuTemperature: _optionalDouble(json['peak_cpu_temperature']),
      peakGpuTemperature: _optionalDouble(json['peak_gpu_temperature']),
      peakRamUsage: _optionalDouble(json['peak_ram_usage']),
      peakGpuUsage: _optionalDouble(json['peak_gpu_usage']),
      avgCpuClock: _optionalDouble(json['avg_cpu_clock']),
      avgGpuPower: _optionalDouble(json['avg_gpu_power']),
      avgCpuPower: _optionalDouble(json['avg_cpu_power']),
      maxCpuUsage: _optionalDouble(json['max_cpu_usage']),
      maxGpuUsage: _optionalDouble(json['max_gpu_usage']),
      totalSamples: (json['total_samples'] as num?)?.toInt() ?? 0,
      hardwaremonVersion: json['hardwaremon_version']?.toString() ?? 'Unknown',
      status: json['status']?.toString() ?? 'completed',
      game: gameJson == null ? null : GameMetadata.fromJson(gameJson),
      activeProcesses: (json['active_processes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => GamingProcess.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      latestSample: sampleJson == null
          ? null
          : GamingSample.fromJson(sampleJson),
    );
  }
}

class GamingEvent {
  final String id;
  final String type;
  final String title;
  final String body;
  final String sessionId;
  final String gameName;
  final DateTime timestamp;

  const GamingEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.sessionId,
    required this.gameName,
    required this.timestamp,
  });

  factory GamingEvent.fromJson(Map<String, dynamic> json) {
    return GamingEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'event',
      title: json['title']?.toString() ?? 'Gaming event',
      body: json['body']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      gameName: json['game_name']?.toString() ?? 'Unknown game',
      timestamp: _parseDate(json['timestamp']),
    );
  }
}

class GamingCurrent {
  final bool active;
  final GamingSession? session;
  final GamingEvent? lastEvent;
  final int knownGames;
  final double pollIntervalSeconds;

  const GamingCurrent({
    required this.active,
    required this.session,
    required this.lastEvent,
    required this.knownGames,
    required this.pollIntervalSeconds,
  });

  factory GamingCurrent.fromJson(Map<String, dynamic> json) {
    final sessionJson = _mapOrNull(json['session']);
    final eventJson = _mapOrNull(json['last_event']);
    return GamingCurrent(
      active: json['active'] == true,
      session: sessionJson == null ? null : GamingSession.fromJson(sessionJson),
      lastEvent: eventJson == null ? null : GamingEvent.fromJson(eventJson),
      knownGames: (json['known_games'] as num?)?.toInt() ?? 0,
      pollIntervalSeconds:
          (json['poll_interval_seconds'] as num?)?.toDouble() ?? 5,
    );
  }
}

class GamingGameAggregate {
  final String gameName;
  final int sessions;
  final double durationSeconds;

  const GamingGameAggregate({
    required this.gameName,
    required this.sessions,
    required this.durationSeconds,
  });

  factory GamingGameAggregate.fromJson(Map<String, dynamic> json) {
    return GamingGameAggregate(
      gameName: json['game_name']?.toString() ?? 'Unknown game',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GamingStatistics {
  final int totalSessions;
  final double totalGamingSeconds;
  final double totalGamingHours;
  final double averageSessionSeconds;
  final GamingGameAggregate? mostPlayedGame;
  final GamingSession? longestSession;
  final GamingSession? hottestRecordedSession;
  final double? averageCpuTemperature;
  final double? averageGpuTemperature;
  final int gamesPlayed;
  final double? largestGpuUsage;
  final double? largestCpuUsage;
  final int knownGames;

  const GamingStatistics({
    required this.totalSessions,
    required this.totalGamingSeconds,
    required this.totalGamingHours,
    required this.averageSessionSeconds,
    required this.mostPlayedGame,
    required this.longestSession,
    required this.hottestRecordedSession,
    required this.averageCpuTemperature,
    required this.averageGpuTemperature,
    required this.gamesPlayed,
    required this.largestGpuUsage,
    required this.largestCpuUsage,
    required this.knownGames,
  });

  const GamingStatistics.empty()
    : totalSessions = 0,
      totalGamingSeconds = 0,
      totalGamingHours = 0,
      averageSessionSeconds = 0,
      mostPlayedGame = null,
      longestSession = null,
      hottestRecordedSession = null,
      averageCpuTemperature = null,
      averageGpuTemperature = null,
      gamesPlayed = 0,
      largestGpuUsage = null,
      largestCpuUsage = null,
      knownGames = 0;

  factory GamingStatistics.fromJson(Map<String, dynamic> json) {
    final mostPlayed = _mapOrNull(json['most_played_game']);
    final longest = _mapOrNull(json['longest_session']);
    final hottest = _mapOrNull(json['hottest_recorded_session']);
    return GamingStatistics(
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalGamingSeconds:
          (json['total_gaming_seconds'] as num?)?.toDouble() ?? 0,
      totalGamingHours: (json['total_gaming_hours'] as num?)?.toDouble() ?? 0,
      averageSessionSeconds:
          (json['average_session_seconds'] as num?)?.toDouble() ?? 0,
      mostPlayedGame: mostPlayed == null
          ? null
          : GamingGameAggregate.fromJson(mostPlayed),
      longestSession: longest == null ? null : GamingSession.fromJson(longest),
      hottestRecordedSession: hottest == null
          ? null
          : GamingSession.fromJson(hottest),
      averageCpuTemperature: _optionalDouble(json['average_cpu_temperature']),
      averageGpuTemperature: _optionalDouble(json['average_gpu_temperature']),
      gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
      largestGpuUsage: _optionalDouble(json['largest_gpu_usage']),
      largestCpuUsage: _optionalDouble(json['largest_cpu_usage']),
      knownGames: (json['known_games'] as num?)?.toInt() ?? 0,
    );
  }
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

DateTime _parseDate(dynamic value) {
  return _parseOptionalDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseOptionalDate(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  final normalized =
      text.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(text)
      ? text
      : '${text}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'unknown') {
    return null;
  }
  return text;
}
