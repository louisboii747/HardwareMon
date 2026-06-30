import sqlite3
import tempfile
import time
import unittest
from pathlib import Path

from benchmark.service import (
    BENCHMARK_VERSION,
    BenchmarkAlreadyRunningError,
    BenchmarkConfig,
    BenchmarkService,
)
from database.database import init_benchmark_schema


class BenchmarkServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.database_path = self.root / "hardwaremon-test.db"

        def connection_factory():
            conn = sqlite3.connect(self.database_path, timeout=5)
            conn.row_factory = sqlite3.Row
            return conn

        self.connection_factory = connection_factory
        conn = self.connection_factory()
        init_benchmark_schema(conn)
        conn.commit()
        conn.close()

    def tearDown(self):
        self.temp_dir.cleanup()

    def _service(self, cpu_seconds=0.04):
        return BenchmarkService(
            config=BenchmarkConfig(
                cpu_single_seconds=cpu_seconds,
                cpu_multi_seconds=cpu_seconds,
                memory_seconds=0.03,
                memory_buffer_bytes=1024 * 1024,
                disk_file_bytes=1024 * 1024,
                disk_chunk_bytes=256 * 1024,
                max_cpu_workers=2,
                pbkdf2_iterations=50,
            ),
            connection_factory=self.connection_factory,
            temp_dir_factory=lambda: self.root,
            hardware_profile_factory=lambda _path: {
                "cpu_cores": 4,
                "cpu_threads": 8,
                "gpu_model": "Test GPU",
                "ram_speed_mhz": 3200,
                "storage_type": "NVMe",
                "operating_system": "TestOS",
            },
        )

    def test_service_lifecycle_moves_from_idle_to_completed(self):
        service = self._service()
        self.assertEqual(service.get_status()["status"], "idle")

        started = service.start()
        self.assertEqual(started["status"], "running")
        self.assertIsNotNone(started["run_id"])

        service.wait(timeout=5)
        completed = service.get_status()
        self.assertEqual(completed["status"], "completed")
        self.assertEqual(completed["progress"], 100.0)
        self.assertIsInstance(completed["result_id"], int)

    def test_start_rejects_duplicate_active_run(self):
        service = self._service(cpu_seconds=0.3)
        service.start()
        with self.assertRaises(BenchmarkAlreadyRunningError):
            service.start()
        service.cancel()
        service.wait(timeout=5)

    def test_result_schema_contains_scores_and_raw_measurements(self):
        service = self._service()
        service.start()
        service.wait(timeout=5)
        result = service.latest_result()

        self.assertIsNotNone(result)
        for key in (
            "id",
            "timestamp",
            "device_name",
            "platform",
            "cpu_model",
            "cpu_cores",
            "cpu_threads",
            "gpu_model",
            "ram_total",
            "ram_speed_mhz",
            "storage_type",
            "operating_system",
            "benchmark_version",
            "overall_score",
            "cpu_score",
            "memory_score",
            "disk_score",
            "duration",
            "raw_result",
        ):
            self.assertIn(key, result)
        self.assertEqual(result["benchmark_version"], BENCHMARK_VERSION)
        self.assertEqual(result["cpu_cores"], 4)
        self.assertEqual(result["gpu_model"], "Test GPU")
        self.assertEqual(result["storage_type"], "NVMe")
        self.assertIn("cpu_single", result["raw_result"])
        self.assertIn("disk", result["raw_result"])

    def test_results_persist_across_service_instances(self):
        service = self._service()
        service.start()
        service.wait(timeout=5)

        reloaded = self._service()
        results = reloaded.list_results()
        self.assertEqual(len(results), 1)
        self.assertGreater(results[0]["overall_score"], 0)

        conn = self.connection_factory()
        columns = {row["name"] for row in conn.execute("PRAGMA table_info(benchmark_results)")}
        conn.close()
        self.assertIn("raw_result_json", columns)
        self.assertIn("benchmark_version", columns)

    def test_schema_migrates_existing_v1_results_additively(self):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        conn.execute(
            """
            CREATE TABLE benchmark_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                device_name TEXT NOT NULL,
                platform TEXT NOT NULL,
                cpu_model TEXT NOT NULL,
                ram_total INTEGER NOT NULL,
                benchmark_version TEXT NOT NULL,
                overall_score INTEGER NOT NULL,
                cpu_score INTEGER NOT NULL,
                memory_score INTEGER NOT NULL,
                disk_score INTEGER NOT NULL,
                duration REAL NOT NULL,
                raw_result_json TEXT NOT NULL
            )
            """
        )

        init_benchmark_schema(conn)

        columns = {row["name"] for row in conn.execute("PRAGMA table_info(benchmark_results)")}
        conn.close()
        self.assertTrue(
            {
                "cpu_cores",
                "cpu_threads",
                "gpu_model",
                "ram_speed_mhz",
                "storage_type",
                "operating_system",
            }.issubset(columns)
        )

    def test_active_run_can_be_cancelled_without_persisting_partial_result(self):
        service = self._service(cpu_seconds=0.8)
        service.start()
        deadline = time.monotonic() + 1
        while service.get_status()["progress"] == 0 and time.monotonic() < deadline:
            time.sleep(0.005)

        service.cancel()
        service.wait(timeout=5)

        self.assertEqual(service.get_status()["status"], "cancelled")
        self.assertEqual(service.list_results(), [])
        self.assertEqual(
            list((self.root / "benchmark-temp").glob("hardwaremon-*.tmp")), []
        )


if __name__ == "__main__":
    unittest.main()
