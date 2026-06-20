import os
import tempfile
import unittest
import json
from unittest.mock import patch

from telemetry.storage import (
    _forecast,
    _health_status,
    _linux_metadata,
    _storage_score,
    collect_storage_stats,
)


class _Row(dict):
    pass


class StorageHealthTests(unittest.TestCase):
    def test_capacity_temperature_and_smart_drive_health(self):
        self.assertEqual(_health_status(40, 38, "Passed"), "healthy")
        self.assertEqual(_health_status(88, 38, "Passed"), "warning")
        self.assertEqual(_health_status(40, 68, "Passed"), "critical")
        self.assertEqual(_health_status(40, None, "Failed"), "critical")

    def test_storage_score_degrades_without_becoming_negative(self):
        self.assertGreater(_storage_score(45, 35, "Passed"), 90)
        self.assertLess(_storage_score(96, 70, "Failed"), 30)
        self.assertGreaterEqual(_storage_score(100, 100, "Failed"), 0)


class StorageForecastTests(unittest.TestCase):
    def test_positive_capacity_trend_produces_days_until_full(self):
        rows = [
            _Row(timestamp="2026-06-01 00:00:00", capacity_percent=50),
            _Row(timestamp="2026-06-06 00:00:00", capacity_percent=55),
            _Row(timestamp="2026-06-11 00:00:00", capacity_percent=60),
        ]

        forecast = _forecast(rows)

        self.assertAlmostEqual(forecast["days_until_full"], 40.0)
        self.assertGreater(forecast["trend_per_day"], 0)


class StorageTelemetryTests(unittest.TestCase):
    @patch("telemetry.storage._linux_smart_metadata", return_value={})
    @patch("telemetry.storage._run_command")
    def test_linux_lsblk_maps_partition_to_physical_drive(self, run_mock, _smart_mock):
        run_mock.return_value = json.dumps(
            {
                "blockdevices": [
                    {
                        "name": "nvme0n1",
                        "kname": "nvme0n1",
                        "path": "/dev/nvme0n1",
                        "model": "Example NVMe",
                        "serial": "SERIAL",
                        "tran": "nvme",
                        "children": [
                            {
                                "name": "nvme0n1p2",
                                "kname": "nvme0n1p2",
                                "path": "/dev/nvme0n1p2",
                                "mountpoints": ["/"],
                                "fstype": "ext4",
                            }
                        ],
                    }
                ]
            }
        )

        metadata = _linux_metadata()

        root = metadata[os.path.normcase("/")]
        self.assertEqual(root["io_key"], "nvme0n1")
        self.assertEqual(root["model"], "Example NVMe")
        self.assertEqual(root["interface_type"], "nvme")

    @patch("telemetry.storage._platform_metadata", return_value={})
    @patch("telemetry.storage.psutil.disk_io_counters", return_value={})
    def test_detected_partition_has_capacity_with_unavailable_optional_metadata(
        self,
        _io_mock,
        _metadata_mock,
    ):
        with tempfile.TemporaryDirectory() as directory:
            partition = type(
                "Partition",
                (),
                {
                    "mountpoint": directory,
                    "fstype": "testfs",
                    "device": "test-device",
                },
            )()
            usage = type(
                "Usage",
                (),
                {"total": 1000, "used": 400, "free": 600, "percent": 40},
            )()
            with patch(
                "telemetry.storage.psutil.disk_partitions",
                return_value=[partition],
            ), patch("telemetry.storage.psutil.disk_usage", return_value=usage):
                snapshot = collect_storage_stats()

        self.assertEqual(len(snapshot["drives"]), 1)
        self.assertEqual(snapshot["drives"][0]["filesystem"], "testfs")
        self.assertEqual(snapshot["drives"][0]["model"], "Unavailable")
        self.assertIsNone(snapshot["drives"][0]["temperature_c"])


if __name__ == "__main__":
    unittest.main()
