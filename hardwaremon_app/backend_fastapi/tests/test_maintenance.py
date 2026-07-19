import unittest
from unittest import mock

try:
    from backend_fastapi.routes import optimization
except ModuleNotFoundError:
    from routes import optimization


class MaintenanceFactsTests(unittest.TestCase):
    def test_recommends_restart_after_fourteen_days(self):
        now = 2_000_000.0
        boot = now - (15 * 24 * 60 * 60)
        fake_psutil = mock.Mock()
        fake_psutil.boot_time.return_value = boot
        fake_psutil.sensors_battery.return_value = None

        with mock.patch.dict("sys.modules", {"psutil": fake_psutil}), mock.patch.object(
            optimization.time, "time", return_value=now
        ):
            result = optimization._maintenance_facts()

        self.assertEqual(result["uptime_seconds"], 15 * 24 * 60 * 60)
        self.assertTrue(result["restart_recommended"])
        self.assertIsNone(result["battery"])
        self.assertEqual(result["providers"]["driver_status"], "planned")


if __name__ == "__main__":
    unittest.main()
