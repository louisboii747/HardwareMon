import subprocess
import unittest
from unittest.mock import Mock, patch

from telemetry.network import (
    PingRequest,
    _interface_priority,
    collect_network_stats,
    normalize_target,
    ping_target,
)


class NetworkTargetValidationTests(unittest.TestCase):
    def test_http_url_is_normalized_to_its_hostname(self):
        display_target, host = normalize_target(" https://GitHub.com/openai/ ")

        self.assertEqual(display_target, "https://GitHub.com/openai/")
        self.assertEqual(host, "github.com")

    def test_shell_metacharacters_are_rejected(self):
        with self.assertRaises(ValueError):
            normalize_target("google.com && whoami")

        with self.assertRaises(ValueError):
            normalize_target("1.1.1.1; shutdown")

    def test_private_router_address_is_allowed(self):
        _, host = normalize_target("192.168.1.1")
        self.assertEqual(host, "192.168.1.1")


class NetworkPingTests(unittest.TestCase):
    @patch("telemetry.network.platform.system", return_value="Windows")
    @patch("telemetry.network._resolve_target", return_value="1.1.1.1")
    @patch("telemetry.network.subprocess.run")
    def test_ping_uses_argument_list_and_resolved_address(
        self,
        run_mock,
        _resolve_mock,
        _platform_mock,
    ):
        run_mock.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=(
                "Reply from 1.1.1.1: bytes=32 time=12ms TTL=57\n"
                "Reply from 1.1.1.1: bytes=32 time=18ms TTL=57\n"
            ),
            stderr="",
        )

        result = ping_target(PingRequest(target="https://cloudflare.com", count=2))

        command = run_mock.call_args.args[0]
        options = run_mock.call_args.kwargs
        self.assertIsInstance(command, list)
        self.assertEqual(command[-1], "1.1.1.1")
        self.assertFalse(options["shell"])
        self.assertTrue(result["reachable"])
        self.assertEqual(result["average_ms"], 15.0)
        self.assertEqual(result["jitter_ms"], 6.0)
        self.assertEqual(result["packet_loss_percent"], 0.0)

    @patch("telemetry.network._resolve_target", return_value="8.8.8.8")
    @patch("telemetry.network.subprocess.run")
    def test_partial_replies_report_packet_loss(self, run_mock, _resolve_mock):
        run_mock.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="64 bytes from 8.8.8.8: time=24.2 ms\n",
            stderr="",
        )

        result = ping_target(PingRequest(target="8.8.8.8", count=4))

        self.assertTrue(result["reachable"])
        self.assertEqual(result["samples"], 1)
        self.assertEqual(result["packet_loss_percent"], 75.0)

    def test_invalid_target_returns_structured_error(self):
        result = ping_target(PingRequest(target="github.com | calc"))

        self.assertFalse(result["reachable"])
        self.assertEqual(result["samples"], 0)
        self.assertIsNotNone(result["error"])


class NetworkTelemetryTests(unittest.TestCase):
    def test_outbound_route_adapter_beats_idle_host_only_adapter(self):
        host_only = {
            "is_up": True,
            "is_loopback": False,
            "is_virtual": False,
            "ipv4": "192.168.56.1",
            "download_bps": 0.0,
            "upload_bps": 0.0,
            "bytes_received": 0,
            "bytes_sent": 0,
        }
        wifi = {
            "is_up": True,
            "is_loopback": False,
            "is_virtual": False,
            "ipv4": "192.168.1.249",
            "download_bps": 1200.0,
            "upload_bps": 400.0,
            "bytes_received": 50_000_000,
            "bytes_sent": 2_000_000,
        }

        self.assertGreater(
            _interface_priority(wifi, "192.168.1.249"),
            _interface_priority(host_only, "192.168.1.249"),
        )

    @patch("telemetry.network._outbound_local_ip", return_value="192.168.1.249")
    @patch("telemetry.network._default_gateway", return_value="192.168.1.1")
    @patch("telemetry.network.psutil.net_if_stats")
    @patch("telemetry.network.psutil.net_if_addrs")
    @patch("telemetry.network.psutil.net_io_counters")
    def test_collection_selects_interface_matching_outbound_route(
        self,
        counters_mock,
        addresses_mock,
        stats_mock,
        _gateway_mock,
        _outbound_mock,
    ):
        counter = lambda received, sent: Mock(
            bytes_recv=received,
            bytes_sent=sent,
            packets_recv=1,
            packets_sent=1,
        )
        counters_mock.return_value = {
            "Ethernet 2": counter(0, 0),
            "WiFi": counter(1000, 500),
        }
        stats_mock.return_value = {
            "Ethernet 2": Mock(isup=True, speed=1000, mtu=1500),
            "WiFi": Mock(isup=True, speed=866, mtu=1500),
        }
        address = lambda value: Mock(family=__import__("socket").AF_INET, address=value)
        addresses_mock.return_value = {
            "Ethernet 2": [address("192.168.56.1")],
            "WiFi": [address("192.168.1.249")],
        }

        result = collect_network_stats()

        self.assertEqual(result["active_interface"], "WiFi")
        self.assertEqual(result["local_ip"], "192.168.1.249")

    @patch("telemetry.network._default_gateway", return_value=None)
    @patch("telemetry.network._outbound_local_ip", return_value=None)
    @patch("telemetry.network.psutil.net_if_stats", return_value={})
    @patch("telemetry.network.psutil.net_if_addrs", return_value={})
    @patch("telemetry.network.psutil.net_io_counters", return_value={})
    def test_missing_adapter_data_degrades_to_offline(
        self,
        _counters_mock,
        _addresses_mock,
        _stats_mock,
        _outbound_mock,
        _gateway_mock,
    ):
        result = collect_network_stats()

        self.assertEqual(result["connection_status"], "offline")
        self.assertEqual(result["interfaces"], [])
        self.assertEqual(result["download_bps"], 0.0)


if __name__ == "__main__":
    unittest.main()
