import importlib
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from app_paths import ensure_app_paths, resolve_app_paths


class AppPathsTests(unittest.TestCase):
    def test_windows_prefers_local_app_data(self):
        paths = resolve_app_paths(
            {"LOCALAPPDATA": r"C:\Users\test\AppData\Local"}, system="Windows"
        )
        self.assertEqual(paths.source, "LOCALAPPDATA")
        self.assertFalse(paths.fallback_used)
        self.assertTrue(str(paths.data_dir).endswith("HardwareMon"))

    def test_windows_survives_missing_home_and_profile(self):
        with tempfile.TemporaryDirectory() as root:
            paths = resolve_app_paths({}, system="Windows", temp_root=root)
            self.assertEqual(paths.source, "TEMP")
            self.assertTrue(paths.fallback_used)
            self.assertEqual(paths.data_dir, (Path(root) / "HardwareMon").resolve())

    def test_windows_uses_profile_only_as_controlled_fallback(self):
        paths = resolve_app_paths(
            {"USERPROFILE": r"C:\Users\test"}, system="Windows"
        )
        self.assertEqual(paths.source, "USERPROFILE")
        self.assertTrue(paths.fallback_used)

    def test_linux_respects_xdg_then_home(self):
        xdg = resolve_app_paths({"XDG_DATA_HOME": "/data"}, system="Linux")
        home = resolve_app_paths({"HOME": "/home/test"}, system="Linux")
        self.assertEqual(xdg.source, "XDG_DATA_HOME")
        self.assertTrue(str(xdg.data_dir).replace("\\", "/").endswith("/data/hardwaremon"))
        self.assertEqual(home.source, "HOME")
        self.assertTrue(
            str(home.data_dir).replace("\\", "/").endswith("/home/test/.local/share/hardwaremon")
        )

    def test_macos_uses_application_support(self):
        paths = resolve_app_paths({"HOME": "/Users/test"}, system="Darwin")
        self.assertEqual(paths.source, "HOME")
        self.assertTrue(
            str(paths.data_dir)
            .replace("\\", "/")
            .endswith("/Users/test/Library/Application Support/HardwareMon")
        )

    def test_path_creation_and_absolute_database_path(self):
        with tempfile.TemporaryDirectory() as root:
            paths = resolve_app_paths(
                {"HARDWAREMON_PORTABLE_ROOT": str(Path(root) / "profile")},
                system="Windows",
            )
            ensured = ensure_app_paths(paths)
            self.assertTrue(ensured.data_dir.is_dir())
            self.assertTrue(ensured.database_path.is_absolute())

    def test_frozen_like_import_does_not_resolve_home(self):
        with mock.patch.object(Path, "home", side_effect=RuntimeError("no home")):
            with mock.patch.object(sys, "frozen", True, create=True):
                module = importlib.import_module("routes.plugins")
                importlib.reload(module)


if __name__ == "__main__":
    unittest.main()
