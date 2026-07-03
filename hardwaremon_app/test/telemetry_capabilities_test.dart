import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_capabilities.dart';

void main() {
  test(
    'macOS fallback keeps core monitoring and disables restricted sensors',
    () {
      final capabilities = TelemetryCapabilities.fromJson(const {
        'supports_process_list': true,
        'supports_process_kill': false,
        'supports_cpu_temperature': false,
        'supports_gpu_temperature': false,
        'supports_power_metrics': false,
        'supports_battery': true,
      }, isMacOS: true);

      expect(capabilities.supportsProcessList, isTrue);
      expect(capabilities.supportsProcessKill, isFalse);
      expect(capabilities.supportsCpuTemperature, isFalse);
      expect(capabilities.supportsGpuTemperature, isFalse);
      expect(capabilities.supportsPowerMetrics, isFalse);
      expect(capabilities.supportsBattery, isTrue);
      expect(capabilities.supportsCpuUsage, isTrue);
      expect(capabilities.supportsMemory, isTrue);
      expect(capabilities.supportsHistoricalMonitoring, isTrue);
    },
  );

  test('platform information preserves Apple chip and model identity', () {
    final platform = TelemetryPlatformInfo.fromJson(const {
      'system': 'Darwin',
      'name': 'macOS',
      'version': '15.5',
      'architecture': 'arm64',
      'device_name': 'MacBook-Air',
      'model_identifier': 'Mac16,2',
      'model_name': 'MacBook Air',
      'chip_name': 'Apple M4',
    });

    expect(platform.system, 'Darwin');
    expect(platform.architecture, 'arm64');
    expect(platform.chipName, 'Apple M4');
    expect(platform.modelIdentifier, 'Mac16,2');
  });
}
