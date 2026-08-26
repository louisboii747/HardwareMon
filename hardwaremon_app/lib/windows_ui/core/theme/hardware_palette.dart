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
    HardwareDomain.cpu => const Color(0xFF255E85),
    HardwareDomain.memory => const Color(0xFF66879C),
    HardwareDomain.gpu => const Color(0xFF3F7562),
    HardwareDomain.network => const Color(0xFF8B6D3D),
    HardwareDomain.storage => const Color(0xFF87584C),
    HardwareDomain.battery => const Color(0xFF557A55),
    HardwareDomain.thermal => const Color(0xFFB5483B),
    HardwareDomain.power => const Color(0xFF967B3D),
    HardwareDomain.cooling => const Color(0xFF4D7887),
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
  static const healthy = Color(0xFF39764B);
  static const informative = Color(0xFF255E85);
  static const caution = Color(0xFF9A7338);
  static const critical = Color(0xFFB5483B);

  static Color forScore(int score) {
    if (score >= 82) return healthy;
    if (score >= 65) return informative;
    if (score >= 45) return caution;
    return critical;
  }
}
