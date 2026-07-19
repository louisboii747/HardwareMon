import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/services/companion_service.dart';

void main() {
  test('plugin descriptors decode a capability-only manifest', () {
    final plugin = PluginDescriptor.fromJson({
      'id': 'org.hardwaremon.prometheus',
      'name': 'Prometheus Exporter',
      'version': '1.2.0',
      'enabled': true,
      'capabilities': ['telemetry.read', 'network.listen'],
    });

    expect(plugin.id, 'org.hardwaremon.prometheus');
    expect(plugin.enabled, isTrue);
    expect(plugin.capabilities, ['telemetry.read', 'network.listen']);
  });

  test('runtime plugin state and grants decode from broker response', () {
    final plugin = PluginDescriptor.fromJson({
      'id': 'org.hardwaremon.prometheus',
      'name': 'Prometheus Exporter',
      'version': '1.0.0',
      'publisher': 'HardwareMon',
      'official': true,
      'enabled': true,
      'approved': true,
      'valid': true,
      'status': 'running',
      'pid': 4242,
      'restart_count': 2,
      'capabilities': ['telemetry.read', 'network.listen'],
      'granted_capabilities': ['telemetry.read', 'network.listen'],
    });

    expect(plugin.status, 'running');
    expect(plugin.pid, 4242);
    expect(plugin.official, isTrue);
    expect(plugin.approved, isTrue);
    expect(plugin.grantedCapabilities, hasLength(2));
  });

  test('portable mode info keeps its explicit runtime reason', () {
    const info = PortableModeInfo(
      active: true,
      dataDirectory: r'E:\HardwareMonData',
      reason: 'portable.flag found beside HardwareMon',
    );

    expect(info.active, isTrue);
    expect(info.reason, contains('portable.flag'));
  });
}
