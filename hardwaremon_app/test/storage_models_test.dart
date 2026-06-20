import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/storage_models.dart';

void main() {
  test('storage models preserve unavailable optional telemetry', () {
    final snapshot = StorageSnapshot.fromJson({
      'sampled_at': '2026-06-20T12:00:00Z',
      'total_capacity': 1000,
      'used_capacity': 400,
      'free_capacity': 600,
      'used_percent': 40,
      'read_bps': 0,
      'write_bps': 0,
      'peak_read_bps': 0,
      'peak_write_bps': 0,
      'temperature_c': null,
      'health_status': 'healthy',
      'storage_score': 96,
      'insights': const [],
      'drives': [
        {
          'id': '/',
          'mount_point': '/',
          'label': '',
          'filesystem': 'ext4',
          'device': '/dev/nvme0n1p2',
          'model': 'Example NVMe',
          'serial': null,
          'interface_type': 'NVMe',
          'total_bytes': 1000,
          'used_bytes': 400,
          'free_bytes': 600,
          'used_percent': 40,
          'read_bps': 0,
          'write_bps': 0,
          'temperature_c': null,
          'health_status': 'healthy',
          'smart_status': null,
          'removable': false,
          'score': 96,
          'insights': const [],
        },
      ],
    });

    expect(snapshot.drives, hasLength(1));
    expect(snapshot.drives.single.displayName, '/');
    expect(snapshot.drives.single.temperatureC, isNull);
    expect(snapshot.drives.single.smartStatus, isNull);
    expect(snapshot.drives.single.health, StorageHealth.healthy);
  });

  test('critical backend health maps to critical UI state', () {
    expect(storageHealthFromString('critical'), StorageHealth.critical);
    expect(storageHealthFromString('warning'), StorageHealth.warning);
    expect(storageHealthFromString(null), StorageHealth.healthy);
  });
}
