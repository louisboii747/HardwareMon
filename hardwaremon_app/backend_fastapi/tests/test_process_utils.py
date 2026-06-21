import os
import subprocess
import unittest

from process_utils import hidden_process_kwargs


class HiddenProcessTests(unittest.TestCase):
    def test_background_processes_are_hidden_on_windows(self):
        kwargs = hidden_process_kwargs()

        if os.name == "nt":
            self.assertEqual(
                kwargs["creationflags"],
                getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            self.assertTrue(
                kwargs["startupinfo"].dwFlags & subprocess.STARTF_USESHOWWINDOW
            )
            self.assertEqual(kwargs["startupinfo"].wShowWindow, subprocess.SW_HIDE)
        else:
            self.assertEqual(kwargs, {})


if __name__ == "__main__":
    unittest.main()
