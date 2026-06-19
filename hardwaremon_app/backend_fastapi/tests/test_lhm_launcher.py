import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock
import xml.etree.ElementTree as ET

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

import lhm_launcher


class LibreHardwareMonitorLauncherTests(unittest.TestCase):
    def test_configure_lhm_creates_web_server_config(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            lhm_launcher.configure_lhm(temp_dir)

            config_path = Path(temp_dir) / "LibreHardwareMonitor.config"
            settings = ET.parse(config_path).getroot().find("./appSettings")

            self.assertIsNotNone(settings)
            values = {
                entry.get("key"): entry.get("value")
                for entry in settings.findall("add")
            }
            self.assertEqual(values["runWebServerMenuItem"], "true")
            self.assertEqual(values["listenerIp"], "127.0.0.1")
            self.assertEqual(values["listenerPort"], "8085")
            self.assertEqual(values["authenticationEnabled"], "false")

    def test_prepare_lhm_runtime_copies_bundled_files(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source_dir = root / "bundled"
            runtime_dir = root / "runtime"
            source_dir.mkdir()
            (source_dir / "LibreHardwareMonitor.exe").write_bytes(b"test")

            with mock.patch.object(
                lhm_launcher,
                "get_lhm_runtime_dir",
                return_value=str(runtime_dir),
            ):
                result = lhm_launcher.prepare_lhm_runtime(str(source_dir))

            self.assertEqual(result, str(runtime_dir))
            self.assertEqual(
                (runtime_dir / "LibreHardwareMonitor.exe").read_bytes(),
                b"test",
            )


if __name__ == "__main__":
    unittest.main()
