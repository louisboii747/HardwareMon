from __future__ import annotations

import concurrent.futures
import hashlib
import json
import math
import os
import platform
import tempfile
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

import psutil

from database.database import get_connection, get_data_dir
from benchmark.hardware import collect_hardware_profile


BENCHMARK_VERSION = "1.0"
TERMINAL_STATES = {"completed", "failed", "cancelled"}


class BenchmarkAlreadyRunningError(RuntimeError):
    pass


class BenchmarkNotRunningError(RuntimeError):
    pass


class BenchmarkCancelledError(RuntimeError):
    pass


@dataclass(frozen=True)
class BenchmarkConfig:
    cpu_single_seconds: float = 1.4
    cpu_multi_seconds: float = 1.6
    memory_seconds: float = 1.2
    memory_buffer_bytes: int = 32 * 1024 * 1024
    disk_file_bytes: int = 64 * 1024 * 1024
    disk_chunk_bytes: int = 4 * 1024 * 1024
    max_cpu_workers: int = 16
    pbkdf2_iterations: int = 3_000


class BenchmarkService:
    """Runs one cancellation-aware local benchmark outside the API event loop."""

    def __init__(
        self,
        *,
        config: Optional[BenchmarkConfig] = None,
        connection_factory: Callable[[], Any] = get_connection,
        temp_dir_factory: Callable[[], Path] = get_data_dir,
        hardware_profile_factory: Callable[[Path], Dict[str, Any]] = collect_hardware_profile,
    ) -> None:
        self.config = config or BenchmarkConfig()
        self._connection_factory = connection_factory
        self._temp_dir_factory = temp_dir_factory
        self._hardware_profile_factory = hardware_profile_factory
        self._lock = threading.RLock()
        self._cancel_event = threading.Event()
        self._worker: Optional[threading.Thread] = None
        self._state: Dict[str, Any] = self._idle_state()

    @staticmethod
    def _idle_state() -> Dict[str, Any]:
        return {
            "status": "idle",
            "run_id": None,
            "current_test": None,
            "progress": 0.0,
            "elapsed_time": 0.0,
            "error_message": None,
            "result_id": None,
            "started_at": None,
        }

    def start(self) -> Dict[str, Any]:
        with self._lock:
            if self._state["status"] == "running":
                raise BenchmarkAlreadyRunningError(
                    "A benchmark is already running on this device."
                )

            run_id = str(uuid.uuid4())
            self._cancel_event = threading.Event()
            self._state = {
                "status": "running",
                "run_id": run_id,
                "current_test": "Preparing benchmark",
                "progress": 0.0,
                "elapsed_time": 0.0,
                "error_message": None,
                "result_id": None,
                "started_at": time.monotonic(),
            }
            self._worker = threading.Thread(
                target=self._run,
                args=(run_id,),
                daemon=True,
                name="hardwaremon-benchmark",
            )
            self._worker.start()
            return self.get_status()

    def cancel(self) -> Dict[str, Any]:
        with self._lock:
            if self._state["status"] != "running":
                raise BenchmarkNotRunningError("There is no active benchmark to cancel.")
            self._cancel_event.set()
            self._state["current_test"] = "Cancelling safely"
            return self.get_status()

    def get_status(self) -> Dict[str, Any]:
        with self._lock:
            snapshot = dict(self._state)
            started_at = snapshot.pop("started_at", None)
            if snapshot["status"] == "running" and started_at is not None:
                snapshot["elapsed_time"] = round(time.monotonic() - started_at, 2)
            return snapshot

    def latest_result(self) -> Optional[Dict[str, Any]]:
        results = self.list_results(limit=1)
        return results[0] if results else None

    def list_results(self, limit: int = 20) -> List[Dict[str, Any]]:
        conn = self._connection_factory()
        try:
            rows = conn.execute(
                """
                SELECT * FROM benchmark_results
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
            return [self._row_to_result(row) for row in rows]
        finally:
            conn.close()

    def wait(self, timeout: Optional[float] = None) -> None:
        """Test and shutdown helper; API callers should poll get_status instead."""
        worker = self._worker
        if worker is not None:
            worker.join(timeout)

    def _run(self, run_id: str) -> None:
        started = time.monotonic()
        try:
            self._check_cancelled()
            self._update("Profiling hardware", 1.0)
            hardware_profile = self._hardware_profile_factory(
                Path(self._temp_dir_factory())
            )
            single_ops = self._run_cpu_single()
            multi_ops, workers = self._run_cpu_multi()
            memory_mib_s = self._run_memory()
            disk_read_mib_s, disk_write_mib_s = self._run_disk()
            self._check_cancelled()

            duration = time.monotonic() - started
            scores = self._calculate_scores(
                single_ops=single_ops,
                multi_ops=multi_ops,
                memory_mib_s=memory_mib_s,
                disk_read_mib_s=disk_read_mib_s,
                disk_write_mib_s=disk_write_mib_s,
            )
            raw_result = {
                "cpu_single": {"operations_per_second": round(single_ops, 3)},
                "cpu_multi": {
                    "operations_per_second": round(multi_ops, 3),
                    "workers": workers,
                },
                "memory": {"throughput_mib_s": round(memory_mib_s, 3)},
                "disk": {
                    "read_mib_s": round(disk_read_mib_s, 3),
                    "write_mib_s": round(disk_write_mib_s, 3),
                    "temporary_file_bytes": self.config.disk_file_bytes,
                },
                "scoring": {
                    "version": BENCHMARK_VERSION,
                    "cpu_weight": 0.60,
                    "memory_weight": 0.20,
                    "disk_weight": 0.20,
                },
                "hardware": hardware_profile,
            }
            result_id = self._persist_result(
                scores, duration, raw_result, hardware_profile
            )
            self._finish(
                run_id,
                status="completed",
                progress=100.0,
                current_test="Benchmark complete",
                duration=duration,
                result_id=result_id,
            )
        except BenchmarkCancelledError:
            self._finish(
                run_id,
                status="cancelled",
                progress=self.get_status()["progress"],
                current_test="Benchmark cancelled",
                duration=time.monotonic() - started,
            )
        except Exception as exc:  # Keep the API alive even if a platform probe fails.
            self._finish(
                run_id,
                status="failed",
                progress=self.get_status()["progress"],
                current_test="Benchmark failed",
                duration=time.monotonic() - started,
                error_message=str(exc) or exc.__class__.__name__,
            )

    def _run_cpu_single(self) -> float:
        self._update("CPU single-thread", 5.0)
        duration = max(0.01, self.config.cpu_single_seconds)
        deadline = time.monotonic() + duration
        operations = 0
        payload = b"HardwareMon benchmark v1 single thread"
        while time.monotonic() < deadline:
            self._check_cancelled()
            hashlib.pbkdf2_hmac(
                "sha256", payload, b"hardwaremon", self.config.pbkdf2_iterations
            )
            operations += 1
            elapsed = duration - max(0.0, deadline - time.monotonic())
            self._update("CPU single-thread", 5.0 + 20.0 * min(1.0, elapsed / duration))
        return operations / duration

    def _run_cpu_multi(self) -> tuple[float, int]:
        workers = max(1, min(os.cpu_count() or 1, self.config.max_cpu_workers))
        duration = max(0.01, self.config.cpu_multi_seconds)
        deadline = time.monotonic() + duration
        self._update("CPU multi-thread", 25.0)

        def worker(index: int) -> int:
            count = 0
            payload = f"HardwareMon benchmark v1 worker {index}".encode("ascii")
            while time.monotonic() < deadline and not self._cancel_event.is_set():
                hashlib.pbkdf2_hmac(
                    "sha256", payload, b"hardwaremon", self.config.pbkdf2_iterations
                )
                count += 1
            return count

        with concurrent.futures.ThreadPoolExecutor(
            max_workers=workers, thread_name_prefix="benchmark-cpu"
        ) as executor:
            futures = [executor.submit(worker, index) for index in range(workers)]
            while not all(future.done() for future in futures):
                self._check_cancelled()
                elapsed = duration - max(0.0, deadline - time.monotonic())
                self._update("CPU multi-thread", 25.0 + 25.0 * min(1.0, elapsed / duration))
                concurrent.futures.wait(futures, timeout=0.04)
            operations = sum(future.result() for future in futures)
        self._check_cancelled()
        return operations / duration, workers

    def _run_memory(self) -> float:
        self._update("Memory throughput", 50.0)
        buffer_size = max(1024 * 1024, self.config.memory_buffer_bytes)
        pattern = bytes(range(251))
        source = (pattern * (buffer_size // len(pattern) + 1))[:buffer_size]
        destination = bytearray(buffer_size)
        duration = max(0.01, self.config.memory_seconds)
        started = time.monotonic()
        deadline = started + duration
        copied = 0
        while time.monotonic() < deadline:
            self._check_cancelled()
            destination[:] = source
            copied += buffer_size
            elapsed = time.monotonic() - started
            self._update("Memory throughput", 50.0 + 20.0 * min(1.0, elapsed / duration))
        elapsed = max(0.001, time.monotonic() - started)
        return copied / (1024 * 1024) / elapsed

    def _run_disk(self) -> tuple[float, float]:
        self._update("Disk write", 70.0)
        root = Path(self._temp_dir_factory()) / "benchmark-temp"
        root.mkdir(parents=True, exist_ok=True)
        path: Optional[Path] = None
        chunk_size = max(64 * 1024, self.config.disk_chunk_bytes)
        total_size = max(chunk_size, self.config.disk_file_bytes)
        pattern = bytes(range(239))
        chunk = (pattern * (chunk_size // len(pattern) + 1))[:chunk_size]
        try:
            handle = tempfile.NamedTemporaryFile(
                mode="w+b", prefix="hardwaremon-", suffix=".tmp", dir=root, delete=False
            )
            path = Path(handle.name)
            with handle:
                written = 0
                started = time.monotonic()
                while written < total_size:
                    self._check_cancelled()
                    amount = min(chunk_size, total_size - written)
                    handle.write(chunk[:amount])
                    written += amount
                    self._update("Disk write", 70.0 + 15.0 * written / total_size)
                handle.flush()
                os.fsync(handle.fileno())
                write_elapsed = max(0.001, time.monotonic() - started)

            self._update("Disk read", 85.0)
            read = 0
            started = time.monotonic()
            with path.open("rb", buffering=0) as handle:
                while True:
                    self._check_cancelled()
                    block = handle.read(chunk_size)
                    if not block:
                        break
                    read += len(block)
                    self._update("Disk read", 85.0 + 14.0 * read / total_size)
            read_elapsed = max(0.001, time.monotonic() - started)
            return (
                read / (1024 * 1024) / read_elapsed,
                written / (1024 * 1024) / write_elapsed,
            )
        finally:
            if path is not None:
                try:
                    path.unlink(missing_ok=True)
                except TypeError:  # Python 3.7 compatibility for older bundles.
                    if path.exists():
                        path.unlink()

    @staticmethod
    def _calculate_scores(
        *,
        single_ops: float,
        multi_ops: float,
        memory_mib_s: float,
        disk_read_mib_s: float,
        disk_write_mib_s: float,
    ) -> Dict[str, int]:
        # HardwareMon v1 uses fixed reference rates, so a score near 1000 means
        # "roughly reference performance" and repeated local runs are comparable.
        single_score = 1000.0 * single_ops / 400.0
        multi_score = 1000.0 * multi_ops / 2400.0
        cpu_score = 0.40 * single_score + 0.60 * multi_score
        memory_score = 1000.0 * memory_mib_s / 6000.0
        # Geometric mean prevents one unusually cached disk direction from
        # overwhelming the other direction in the combined disk result.
        disk_score = 1000.0 * math.sqrt(
            max(0.0, disk_read_mib_s) * max(0.0, disk_write_mib_s)
        ) / 500.0
        # Overall v1 weighting: CPU 60%, memory 20%, disk 20%.
        overall_score = 0.60 * cpu_score + 0.20 * memory_score + 0.20 * disk_score
        return {
            "overall_score": max(1, round(overall_score)),
            "cpu_score": max(1, round(cpu_score)),
            "memory_score": max(1, round(memory_score)),
            "disk_score": max(1, round(disk_score)),
        }

    def _persist_result(
        self,
        scores: Dict[str, int],
        duration: float,
        raw_result: Dict[str, Any],
        hardware_profile: Dict[str, Any],
    ) -> int:
        conn = self._connection_factory()
        try:
            cursor = conn.execute(
                """
                INSERT INTO benchmark_results (
                    timestamp, device_name, platform, cpu_model, cpu_cores,
                    cpu_threads, gpu_model, ram_total, ram_speed_mhz,
                    storage_type, operating_system,
                    benchmark_version, overall_score, cpu_score, memory_score,
                    disk_score, duration, raw_result_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    datetime.now(timezone.utc).isoformat(),
                    platform.node() or "Unknown device",
                    platform.platform(),
                    self._cpu_model(),
                    hardware_profile.get("cpu_cores") or 0,
                    hardware_profile.get("cpu_threads") or 0,
                    hardware_profile.get("gpu_model"),
                    int(psutil.virtual_memory().total),
                    hardware_profile.get("ram_speed_mhz"),
                    hardware_profile.get("storage_type"),
                    hardware_profile.get("operating_system") or "Unknown",
                    BENCHMARK_VERSION,
                    scores["overall_score"],
                    scores["cpu_score"],
                    scores["memory_score"],
                    scores["disk_score"],
                    round(duration, 3),
                    json.dumps(raw_result, separators=(",", ":")),
                ),
            )
            conn.commit()
            return int(cursor.lastrowid)
        finally:
            conn.close()

    @staticmethod
    def _cpu_model() -> str:
        model = platform.processor().strip() or os.environ.get("PROCESSOR_IDENTIFIER", "").strip()
        if model:
            return model
        if platform.system() == "Linux":
            try:
                for line in Path("/proc/cpuinfo").read_text(encoding="utf-8").splitlines():
                    if line.lower().startswith("model name"):
                        return line.split(":", 1)[1].strip()
            except (OSError, IndexError):
                pass
        return "Unknown CPU"

    @staticmethod
    def _row_to_result(row: Any) -> Dict[str, Any]:
        result = dict(row)
        raw = result.pop("raw_result_json", "{}")
        try:
            result["raw_result"] = json.loads(raw)
        except (TypeError, json.JSONDecodeError):
            result["raw_result"] = {}
        return result

    def _update(self, current_test: str, progress: float) -> None:
        with self._lock:
            if self._state["status"] != "running":
                return
            self._state["current_test"] = current_test
            self._state["progress"] = round(max(0.0, min(100.0, progress)), 1)

    def _check_cancelled(self) -> None:
        if self._cancel_event.is_set():
            raise BenchmarkCancelledError()

    def _finish(
        self,
        run_id: str,
        *,
        status: str,
        progress: float,
        current_test: str,
        duration: float,
        result_id: Optional[int] = None,
        error_message: Optional[str] = None,
    ) -> None:
        with self._lock:
            if self._state.get("run_id") != run_id:
                return
            self._state.update(
                {
                    "status": status,
                    "current_test": current_test,
                    "progress": round(progress, 1),
                    "elapsed_time": round(duration, 2),
                    "error_message": error_message,
                    "result_id": result_id,
                    "started_at": None,
                }
            )
