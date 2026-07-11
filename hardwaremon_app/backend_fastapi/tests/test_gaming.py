import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from database.database import init_gaming_schema
from gaming.service import GamingService


class GamingServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.database_path = self.root / "hardwaremon-test.db"
        self.games_path = self.root / "games.json"
        self.games_path.write_text(
            json.dumps(
                [
                    {
                        "name": "Test Game",
                        "executables": ["testgame.exe"],
                        "genre": "Benchmark",
                        "publisher": "HardwareMon",
                    },
                    {
                        "name": "Minecraft Java Edition",
                        "executables": ["javaw.exe"],
                        "process_keywords": ["minecraft"],
                    },
                ]
            ),
            encoding="utf-8",
        )
        self.processes = []
        self.stats = {
            "cpu": 40,
            "gpu_usage": 70,
            "ram": 55,
            "cpu_temp": 62,
            "gpu_temp": 68,
            "cpu_clock": 4200,
            "gpu_power": 180,
            "cpu_power": 75,
        }

        def connection_factory():
            conn = sqlite3.connect(self.database_path, timeout=5)
            conn.row_factory = sqlite3.Row
            return conn

        self.connection_factory = connection_factory
        conn = self.connection_factory()
        init_gaming_schema(conn)
        conn.commit()
        conn.close()

    def tearDown(self):
        self.temp_dir.cleanup()

    def _service(self):
        return GamingService(
            games_path=self.games_path,
            process_provider=lambda: list(self.processes),
            stats_collector=lambda: dict(self.stats),
            connection_factory=self.connection_factory,
            hardwaremon_version="test-version",
        )

    def test_session_starts_samples_and_finishes_when_game_exits(self):
        service = self._service()
        self.processes = [
            {
                "pid": 100,
                "name": "testgame.exe",
                "exe": r"C:\Games\Test Game\testgame.exe",
                "cmdline": ["testgame.exe"],
                "create_time": 1.0,
            }
        ]

        service.scan_once()
        current = service.get_current()
        self.assertTrue(current["active"])
        self.assertEqual(current["session"]["game_name"], "Test Game")
        self.assertEqual(current["session"]["total_samples"], 1)

        self.processes = []
        service.scan_once()

        self.assertFalse(service.get_current()["active"])
        history = service.list_sessions()
        self.assertEqual(len(history), 1)
        self.assertEqual(history[0]["game_name"], "Test Game")
        self.assertEqual(history[0]["avg_gpu_usage"], 70.0)
        self.assertEqual(history[0]["peak_gpu_temperature"], 68.0)
        self.assertEqual(history[0]["hardwaremon_version"], "test-version")

    def test_duplicate_scans_do_not_create_duplicate_sessions(self):
        service = self._service()
        self.processes = [
            {
                "pid": 101,
                "name": "testgame.exe",
                "exe": "testgame.exe",
                "cmdline": ["testgame.exe"],
                "create_time": 1.0,
            }
        ]

        service.scan_once()
        first_id = service.get_current()["session"]["id"]
        service.scan_once()

        current = service.get_current()["session"]
        self.assertEqual(current["id"], first_id)
        self.assertEqual(current["total_samples"], 2)
        self.assertEqual(service.list_sessions(), [])

    def test_java_game_requires_minecraft_command_line_keyword(self):
        service = self._service()
        self.processes = [
            {
                "pid": 102,
                "name": "javaw.exe",
                "exe": r"C:\Program Files\Java\javaw.exe",
                "cmdline": ["javaw.exe", "-jar", "unrelated.jar"],
                "create_time": 1.0,
            }
        ]
        self.assertEqual(service.detect_games(), [])

        self.processes[0]["cmdline"] = [
            "javaw.exe",
            "-Dminecraft.client.jar=.minecraft",
        ]
        detected = service.detect_games()
        self.assertEqual(len(detected), 1)
        self.assertEqual(detected[0].game.name, "Minecraft Java Edition")

    def test_statistics_summarise_completed_sessions(self):
        service = self._service()
        self.processes = [
            {
                "pid": 103,
                "name": "testgame.exe",
                "exe": "testgame.exe",
                "cmdline": ["testgame.exe"],
                "create_time": 1.0,
            }
        ]
        service.scan_once()
        self.stats.update(gpu_usage=90, gpu_temp=74, cpu=50)
        service.scan_once()
        self.processes = []
        service.scan_once()

        stats = service.statistics()
        self.assertEqual(stats["total_sessions"], 1)
        self.assertEqual(stats["games_played"], 1)
        self.assertEqual(stats["most_played_game"]["game_name"], "Test Game")
        self.assertEqual(stats["largest_gpu_usage"], 90.0)
        self.assertEqual(stats["largest_cpu_usage"], 50.0)


if __name__ == "__main__":
    unittest.main()
