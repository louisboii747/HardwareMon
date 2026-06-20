import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/network_models.dart';

NetworkInterfaceInfo _interface({
  required String name,
  required String ipv4,
  required bool isUp,
  required int bytesReceived,
  required int bytesSent,
}) {
  return NetworkInterfaceInfo(
    name: name,
    displayName: name,
    isUp: isUp,
    isLoopback: false,
    isVirtual: false,
    connectionStatus: isUp ? 'active' : 'inactive',
    ipv4: ipv4,
    ipv6: null,
    macAddress: null,
    speedMbps: 1000,
    mtu: 1500,
    bytesSent: bytesSent,
    bytesReceived: bytesReceived,
    packetsSent: 0,
    packetsReceived: 0,
    uploadBps: 0,
    downloadBps: 0,
    sessionBytesSent: 0,
    sessionBytesReceived: 0,
  );
}

void main() {
  test('first reading replaces an idle saved adapter with routed adapter', () {
    final snapshot = NetworkSnapshot(
      sampledAt: DateTime(2026, 6, 20),
      connectionStatus: 'online',
      activeInterface: 'WiFi',
      localIp: '192.168.1.249',
      gateway: '192.168.1.1',
      uploadBps: 0,
      downloadBps: 0,
      bytesSent: 100,
      bytesReceived: 1000,
      sessionBytesSent: 0,
      sessionBytesReceived: 0,
      packetsSent: 0,
      packetsReceived: 0,
      interfaces: [
        _interface(
          name: 'Ethernet 2',
          ipv4: '192.168.56.1',
          isUp: true,
          bytesReceived: 0,
          bytesSent: 0,
        ),
        _interface(
          name: 'WiFi',
          ipv4: '192.168.1.249',
          isUp: true,
          bytesReceived: 1000,
          bytesSent: 100,
        ),
      ],
    );

    expect(
      chooseNetworkInterfaceName(snapshot, 'Ethernet 2', firstReading: true),
      'WiFi',
    );
  });

  test('manual active adapter selection is preserved after first reading', () {
    final snapshot = NetworkSnapshot(
      sampledAt: DateTime(2026, 6, 20),
      connectionStatus: 'online',
      activeInterface: 'WiFi',
      localIp: '192.168.1.249',
      gateway: '192.168.1.1',
      uploadBps: 0,
      downloadBps: 0,
      bytesSent: 100,
      bytesReceived: 1000,
      sessionBytesSent: 0,
      sessionBytesReceived: 0,
      packetsSent: 0,
      packetsReceived: 0,
      interfaces: [
        _interface(
          name: 'Ethernet 2',
          ipv4: '192.168.56.1',
          isUp: true,
          bytesReceived: 0,
          bytesSent: 0,
        ),
        _interface(
          name: 'WiFi',
          ipv4: '192.168.1.249',
          isUp: true,
          bytesReceived: 1000,
          bytesSent: 100,
        ),
      ],
    );

    expect(
      chooseNetworkInterfaceName(snapshot, 'Ethernet 2', firstReading: false),
      'Ethernet 2',
    );
  });
}
