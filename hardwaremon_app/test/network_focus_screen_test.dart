import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/network_models.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/screens/network_focus_screen.dart';

void main() {
  testWidgets('network focus renders long adapter details without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final interface = NetworkInterfaceInfo(
      name: 'A very long enterprise network adapter identifier',
      displayName:
          'A very long enterprise network adapter display name for testing',
      isUp: true,
      isLoopback: false,
      isVirtual: false,
      connectionStatus: 'active',
      ipv4: '192.168.100.249',
      ipv6: 'fe80::1234:5678:90ab:cdef',
      macAddress: 'AA-BB-CC-DD-EE-FF',
      speedMbps: 2500,
      mtu: 1500,
      bytesSent: 2000000,
      bytesReceived: 9000000,
      packetsSent: 2000,
      packetsReceived: 9000,
      uploadBps: 240000,
      downloadBps: 870000,
      sessionBytesSent: 100000,
      sessionBytesReceived: 500000,
    );
    final now = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: NetworkFocusScreen(
          title: 'Live Bandwidth',
          value: '1.1 MB/s',
          subtitle: 'Combined throughput',
          icon: Icons.show_chart_rounded,
          accent: Colors.cyanAccent,
          primarySamples: [
            TelemetrySample(timestamp: now, value: 100000),
            TelemetrySample(
              timestamp: now.add(const Duration(seconds: 2)),
              value: 870000,
            ),
          ],
          secondarySamples: [
            TelemetrySample(timestamp: now, value: 50000),
            TelemetrySample(
              timestamp: now.add(const Duration(seconds: 2)),
              value: 240000,
            ),
          ],
          interfaceInfo: interface,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NETWORK FOCUS'), findsOneWidget);
    expect(find.text(interface.displayName), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
