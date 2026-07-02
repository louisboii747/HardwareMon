import 'package:flutter/material.dart';

/// The semantic colour language for hardware domains across HardwareMon.
///
/// Keeping these colours in one place prevents CPU, memory, thermal and power
/// states from drifting between cards, charts, badges and future surfaces.
enum HardwareDomain {
  cpu,
  memory,
  gpu,
  network,
  storage,
  battery,
  thermal,
  power,
  cooling,
}

extension HardwareDomainVisuals on HardwareDomain {
  String get label => switch (this) {
    HardwareDomain.cpu => 'CPU',
    HardwareDomain.memory => 'Memory',
    HardwareDomain.gpu => 'GPU',
    HardwareDomain.network => 'Network',
    HardwareDomain.storage => 'Storage',
    HardwareDomain.battery => 'Battery',
    HardwareDomain.thermal => 'Thermals',
    HardwareDomain.power => 'Power',
    HardwareDomain.cooling => 'Cooling',
  };

  Color get color => switch (this) {
    HardwareDomain.cpu => const Color(0xFF22D3EE),
    HardwareDomain.memory => const Color(0xFFA78BFA),
    HardwareDomain.gpu => const Color(0xFF60A5FA),
    HardwareDomain.network => const Color(0xFF2DD4BF),
    HardwareDomain.storage => const Color(0xFFF59E0B),
    HardwareDomain.battery => const Color(0xFF84CC16),
    HardwareDomain.thermal => const Color(0xFFFB7185),
    HardwareDomain.power => const Color(0xFFFACC15),
    HardwareDomain.cooling => const Color(0xFF38BDF8),
  };

  IconData get icon => switch (this) {
    HardwareDomain.cpu => Icons.memory_rounded,
    HardwareDomain.memory => Icons.view_stream_rounded,
    HardwareDomain.gpu => Icons.developer_board_rounded,
    HardwareDomain.network => Icons.swap_vert_circle_rounded,
    HardwareDomain.storage => Icons.storage_rounded,
    HardwareDomain.battery => Icons.battery_charging_full_rounded,
    HardwareDomain.thermal => Icons.thermostat_rounded,
    HardwareDomain.power => Icons.bolt_rounded,
    HardwareDomain.cooling => Icons.air_rounded,
  };
}

class HardwareStatusColors {
  static const healthy = Color(0xFF34D399);
  static const informative = Color(0xFF38BDF8);
  static const caution = Color(0xFFFBBF24);
  static const critical = Color(0xFFFB7185);

  static Color forScore(int score) {
    if (score >= 82) return healthy;
    if (score >= 65) return informative;
    if (score >= 45) return caution;
    return critical;
  }
}
