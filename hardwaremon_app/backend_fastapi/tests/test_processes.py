import unittest
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from routes import processes


class _Uids:
    def __init__(self, real):
        self.real = real


class _Process:
    def __init__(self, pid=100, uid=501):
        self.pid = pid
        self._uid = uid

    def uids(self):
        return _Uids(self._uid)


class ProcessClassificationTests(unittest.TestCase):
    def test_macos_system_processes_are_hidden_without_hiding_user_apps(self):
        with patch.object(processes, "_OPERATING_SYSTEM", "Darwin"):
            self.assertTrue(
                processes._is_system_process(
                    _Process(uid=88),
                    "WindowServer",
                    "_windowserver",
                )
            )
            self.assertTrue(
                processes._is_system_process(
                    _Process(uid=0),
                    "launchd",
                    "root",
                )
            )
            self.assertFalse(
                processes._is_system_process(
                    _Process(uid=501),
                    "Safari",
                    "louis",
                )
            )


if __name__ == "__main__":
    unittest.main()
