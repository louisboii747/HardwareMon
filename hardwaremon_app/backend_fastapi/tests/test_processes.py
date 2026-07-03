import unittest
import sys
from pathlib import Path
from unittest.mock import patch
from fastapi import HTTPException

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

    def test_macos_process_termination_is_explicitly_unsupported(self):
        with patch.object(processes, "_OPERATING_SYSTEM", "Darwin"):
            with self.assertRaises(HTTPException) as raised:
                processes.kill_process(123)

        self.assertEqual(raised.exception.status_code, 501)
        self.assertIn("macOS restricts process management", raised.exception.detail)


if __name__ == "__main__":
    unittest.main()
