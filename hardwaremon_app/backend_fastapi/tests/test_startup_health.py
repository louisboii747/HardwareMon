import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

import main
from app_paths import resolve_app_paths


class StartupHealthTests(unittest.IsolatedAsyncioTestCase):
    async def test_plugin_failure_degrades_without_preventing_startup(self):
        with TemporaryDirectory() as root:
            paths = resolve_app_paths(
                {"HARDWAREMON_PORTABLE_ROOT": root}, system="Windows"
            )
            with (
                mock.patch.object(main, "ensure_app_paths", return_value=paths),
                mock.patch.object(main, "init_database"),
                mock.patch.object(main, "start_logging"),
                mock.patch.object(main, "start_lhm"),
                mock.patch.object(main.gaming_service, "start"),
                mock.patch.object(main.gaming_service, "stop"),
                mock.patch.object(
                    main, "PluginBroker", side_effect=OSError("plugin store denied")
                ),
            ):
                async with main.lifespan(main.app):
                    self.assertTrue(main.app.state.database_ready)
                    self.assertEqual(main.app.state.plugin_status["state"], "degraded")
                    self.assertIn("plugin store denied", main.app.state.plugin_status["error"])


if __name__ == "__main__":
    unittest.main()
