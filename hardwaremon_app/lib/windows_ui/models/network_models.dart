class NetworkInterfaceInfo {
  final String name;
  final String displayName;
  final bool isUp;
  final bool isLoopback;
  final bool isVirtual;
  final String connectionStatus;
  final String? ipv4;
  final String? ipv6;
  final String? macAddress;
  final int speedMbps;
  final int mtu;
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final double uploadBps;
  final double downloadBps;
  final int sessionBytesSent;
  final int sessionBytesReceived;

  const NetworkInterfaceInfo({
    required this.name,
    required this.displayName,
    required this.isUp,
    required this.isLoopback,
    required this.isVirtual,
    required this.connectionStatus,
    required this.ipv4,
    required this.ipv6,
    required this.macAddress,
    required this.speedMbps,
    required this.mtu,
    required this.bytesSent,
    required this.bytesReceived,
    required this.packetsSent,
    required this.packetsReceived,
    required this.uploadBps,
    required this.downloadBps,
    required this.sessionBytesSent,
    required this.sessionBytesReceived,
  });

  factory NetworkInterfaceInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInterfaceInfo(
      name: json['name']?.toString() ?? 'Unknown adapter',
      displayName:
          json['display_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown adapter',
      isUp: json['is_up'] == true,
      isLoopback: json['is_loopback'] == true,
      isVirtual: json['is_virtual'] == true,
      connectionStatus: json['connection_status']?.toString() ?? 'inactive',
      ipv4: json['ipv4']?.toString(),
      ipv6: json['ipv6']?.toString(),
      macAddress: json['mac_address']?.toString(),
      speedMbps: (json['speed_mbps'] as num?)?.toInt() ?? 0,
      mtu: (json['mtu'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
      bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
      packetsSent: (json['packets_sent'] as num?)?.toInt() ?? 0,
      packetsReceived: (json['packets_received'] as num?)?.toInt() ?? 0,
      uploadBps: (json['upload_bps'] as num?)?.toDouble() ?? 0,
      downloadBps: (json['download_bps'] as num?)?.toDouble() ?? 0,
      sessionBytesSent: (json['session_bytes_sent'] as num?)?.toInt() ?? 0,
      sessionBytesReceived:
          (json['session_bytes_received'] as num?)?.toInt() ?? 0,
    );
  }
}

class NetworkSnapshot {
  final DateTime sampledAt;
  final String connectionStatus;
  final String? activeInterface;
  final String? localIp;
  final String? gateway;
  final double uploadBps;
  final double downloadBps;
  final int bytesSent;
  final int bytesReceived;
  final int sessionBytesSent;
  final int sessionBytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final List<NetworkInterfaceInfo> interfaces;

  const NetworkSnapshot({
    required this.sampledAt,
    required this.connectionStatus,
    required this.activeInterface,
    required this.localIp,
    required this.gateway,
    required this.uploadBps,
    required this.downloadBps,
    required this.bytesSent,
    required this.bytesReceived,
    required this.sessionBytesSent,
    required this.sessionBytesReceived,
    required this.packetsSent,
    required this.packetsReceived,
    required this.interfaces,
  });

  factory NetworkSnapshot.fromJson(Map<String, dynamic> json) {
    final rawInterfaces = json['interfaces'] as List<dynamic>? ?? const [];
    return NetworkSnapshot(
      sampledAt:
          DateTime.tryParse(json['sampled_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      connectionStatus: json['connection_status']?.toString() ?? 'offline',
      activeInterface: json['active_interface']?.toString(),
      localIp: json['local_ip']?.toString(),
      gateway: json['gateway']?.toString(),
      uploadBps: (json['upload_bps'] as num?)?.toDouble() ?? 0,
      downloadBps: (json['download_bps'] as num?)?.toDouble() ?? 0,
      bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
      bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
      sessionBytesSent: (json['session_bytes_sent'] as num?)?.toInt() ?? 0,
      sessionBytesReceived:
          (json['session_bytes_received'] as num?)?.toInt() ?? 0,
      packetsSent: (json['packets_sent'] as num?)?.toInt() ?? 0,
      packetsReceived: (json['packets_received'] as num?)?.toInt() ?? 0,
      interfaces: rawInterfaces
          .whereType<Map>()
          .map(
            (item) =>
                NetworkInterfaceInfo.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

String? chooseNetworkInterfaceName(
  NetworkSnapshot snapshot,
  String? currentName, {
  required bool firstReading,
}) {
  NetworkInterfaceInfo? current;
  NetworkInterfaceInfo? active;
  for (final interface in snapshot.interfaces) {
    if (interface.name == currentName) current = interface;
    if (interface.name == snapshot.activeInterface) active = interface;
  }

  if (current == null) {
    return active?.name ??
        (snapshot.interfaces.isEmpty ? null : snapshot.interfaces.first.name);
  }
  if (!current.isUp && active != null) return active.name;

  final currentHasCounters =
      current.bytesReceived > 0 ||
      current.bytesSent > 0 ||
      current.downloadBps > 0 ||
      current.uploadBps > 0;
  final activeHasCounters =
      active != null &&
      (active.bytesReceived > 0 ||
          active.bytesSent > 0 ||
          active.downloadBps > 0 ||
          active.uploadBps > 0);
  if (firstReading &&
      active != null &&
      active.name != current.name &&
      !currentHasCounters &&
      activeHasCounters) {
    return active.name;
  }
  return current.name;
}

enum PingHealth { online, slow, unreachable, error }

class PingResult {
  final String target;
  final String? resolvedHost;
  final bool reachable;
  final double? latencyMs;
  final double? averageMs;
  final double? minMs;
  final double? maxMs;
  final double? jitterMs;
  final double packetLossPercent;
  final int samples;
  final List<double> sampleLatenciesMs;
  final String? error;
  final DateTime checkedAt;

  const PingResult({
    required this.target,
    required this.resolvedHost,
    required this.reachable,
    required this.latencyMs,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.jitterMs,
    required this.packetLossPercent,
    required this.samples,
    required this.sampleLatenciesMs,
    required this.error,
    required this.checkedAt,
  });

  PingHealth get health {
    if (resolvedHost == null && error != null) return PingHealth.error;
    if (!reachable) return PingHealth.unreachable;
    if ((averageMs ?? latencyMs ?? 0) >= 150 || packetLossPercent > 10) {
      return PingHealth.slow;
    }
    return PingHealth.online;
  }

  String get statusLabel => switch (health) {
    PingHealth.online => 'Online',
    PingHealth.slow => 'Slow',
    PingHealth.unreachable => 'Unreachable',
    PingHealth.error => 'Error',
  };

  factory PingResult.fromJson(Map<String, dynamic> json) {
    final rawLatencies =
        json['sample_latencies_ms'] as List<dynamic>? ?? const [];
    return PingResult(
      target: json['target']?.toString() ?? '',
      resolvedHost: json['resolved_host']?.toString(),
      reachable: json['reachable'] == true,
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
      averageMs: (json['average_ms'] as num?)?.toDouble(),
      minMs: (json['min_ms'] as num?)?.toDouble(),
      maxMs: (json['max_ms'] as num?)?.toDouble(),
      jitterMs: (json['jitter_ms'] as num?)?.toDouble(),
      packetLossPercent:
          (json['packet_loss_percent'] as num?)?.toDouble() ?? 100,
      samples: (json['samples'] as num?)?.toInt() ?? 0,
      sampleLatenciesMs: rawLatencies
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false),
      error: json['error']?.toString(),
      checkedAt:
          DateTime.tryParse(json['checked_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target': target,
      'resolved_host': resolvedHost,
      'reachable': reachable,
      'latency_ms': latencyMs,
      'average_ms': averageMs,
      'min_ms': minMs,
      'max_ms': maxMs,
      'jitter_ms': jitterMs,
      'packet_loss_percent': packetLossPercent,
      'samples': samples,
      'sample_latencies_ms': sampleLatenciesMs,
      'error': error,
      'checked_at': checkedAt.toIso8601String(),
    };
  }
}
