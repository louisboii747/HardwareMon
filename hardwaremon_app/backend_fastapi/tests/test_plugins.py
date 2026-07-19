import io
import json
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

from plugins.broker import PluginBroker, PluginError

RUNNER = """
import json, os, sys
token = os.environ['HARDWAREMON_PLUGIN_TOKEN']
print(json.dumps({'type':'plugin.ready','token':token}), flush=True)
for line in sys.stdin:
    message = json.loads(line)
    if message.get('token') != token:
        continue
    if message.get('type') == 'host.shutdown':
        break
    print(json.dumps({'type':'plugin.heartbeat','token':token}), flush=True)
"""


class PluginBrokerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.data = Path(self.temporary.name) / "data"
        self.bundled = Path(self.temporary.name) / "bundled"
        plugin = self.bundled / "org.hardwaremon.test"
        plugin.mkdir(parents=True)
        (plugin / "hardwaremon-plugin.json").write_text(
            json.dumps(
                {
                    "api_version": 1,
                    "id": "org.hardwaremon.test",
                    "name": "Test Plugin",
                    "version": "1.0.0",
                    "publisher": "HardwareMon Tests",
                    "entrypoint": {"type": "python", "path": "plugin.py"},
                    "capabilities": ["events.publish"],
                }
            ),
            encoding="utf-8",
        )
        (plugin / "plugin.py").write_text(RUNNER, encoding="utf-8")
        self.broker = PluginBroker(
            poll_seconds=0.05,
            data_dir=self.data,
            bundled_root=self.bundled,
        )
        self.broker.start()

    def tearDown(self):
        self.broker.stop()
        self.temporary.cleanup()

    def test_bundled_plugin_requires_explicit_capability_approval(self):
        plugin = self.broker.plugin_details("org.hardwaremon.test")
        self.assertFalse(plugin["approved"])
        with self.assertRaises(PluginError):
            self.broker.set_enabled(plugin["id"], True)

        approved = self.broker.set_grants(plugin["id"], ["events.publish"])
        self.assertTrue(approved["approved"])

    def test_approved_plugin_runs_out_of_process_and_stops_cleanly(self):
        plugin_id = "org.hardwaremon.test"
        self.broker.set_grants(plugin_id, ["events.publish"])
        self.broker.set_enabled(plugin_id, True)
        deadline = time.time() + 3
        details = self.broker.plugin_details(plugin_id)
        while details["status"] != "running" and time.time() < deadline:
            time.sleep(0.05)
            details = self.broker.plugin_details(plugin_id)
        self.assertEqual(details["status"], "running")
        self.assertIsInstance(details["pid"], int)
        self.broker.set_enabled(plugin_id, False)
        self.assertEqual(self.broker.plugin_details(plugin_id)["status"], "stopped")

    def test_manifest_path_escape_is_rejected(self):
        manifest = self.data / "plugins" / "org.hardwaremon.test" / "hardwaremon-plugin.json"
        value = json.loads(manifest.read_text(encoding="utf-8"))
        value["entrypoint"]["path"] = "../outside.py"
        manifest.write_text(json.dumps(value), encoding="utf-8")
        with self.assertRaises(PluginError):
            self.broker.set_grants("org.hardwaremon.test", ["events.publish"])

    def test_archive_install_rejects_traversal_and_activates_valid_package(self):
        malicious = io.BytesIO()
        with zipfile.ZipFile(malicious, "w") as archive:
            archive.writestr("../outside.txt", "no")
        with self.assertRaises(PluginError):
            self.broker.install_archive(malicious.getvalue())

        package = io.BytesIO()
        plugin_id = "com.example.archive"
        manifest = {
            "api_version": 1,
            "id": plugin_id,
            "name": "Archive Plugin",
            "version": "1.0.0",
            "entrypoint": {"type": "python", "path": "plugin.py"},
            "capabilities": [],
        }
        with zipfile.ZipFile(package, "w") as archive:
            archive.writestr(f"{plugin_id}/hardwaremon-plugin.json", json.dumps(manifest))
            archive.writestr(f"{plugin_id}/plugin.py", RUNNER)
        installed = self.broker.install_archive(package.getvalue())
        self.assertEqual(installed["id"], plugin_id)
        self.assertFalse(installed["enabled"])


if __name__ == "__main__":
    unittest.main()
