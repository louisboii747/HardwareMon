from __future__ import annotations

import json
import os
import platform
import threading
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable, Optional, Protocol

import psutil

from database.database import get_connection
from telemetry.system import collect_stats


GAMING_MODE_VERSION = "2.0"
DEFAULT_HARDWAREMON_VERSION = os.environ.get("HARDWAREMON_VERSION", "1.1.0")


@dataclass(frozen=True)
class GameDefinition:
    name: str
    executables: tuple[str, ...]
    icon: str = "gamepad"
    genre: Optional[str] = None
    publisher: Optional[str] = None
    steam_app_id: Optional[str] = None
    process_keywords: tuple[str, ...] = ()

    @classmethod
    def from_json(cls, payload: dict[str, Any]) -> "GameDefinition":
        executables = tuple(
            str(item).strip()
            for item in payload.get("executables", [])
            if str(item).strip()
        )
        keywords = tuple(
            str(item).strip().lower()
            for item in payload.get("process_keywords", [])
            if str(item).strip()
        )
        return cls(
            name=str(payload.get("name") or "Unknown game"),
            executables=executables,
            icon=str(payload.get("icon") or "gamepad"),
            genre=_optional_text(payload.get("genre")),
            publisher=_optional_text(payload.get("publisher")),
            steam_app_id=_optional_text(payload.get("steam_app_id")),
            process_keywords=keywords,
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "executables": list(self.executables),
            "icon": self.icon,
            "genre": self.genre,
            "publisher": self.publisher,
            "steam_app_id": self.steam_app_id,
            "process_keywords": list(self.process_keywords),
        }


class FrameStatsProvider(Protocol):
    """Non-injected frame data bridge implemented by platform collectors."""

    name: str

    def sample(self, process_id: int) -> dict[str, Any]: ...


class JsonFrameStatsProvider:
    """Reads frame stats produced by PresentMon, MangoHud or another bridge.

    The collector writes a small JSON document atomically. Keeping capture out
    of the HardwareMon process avoids renderer injection and anti-cheat risk.
    """

    name = "external-json-bridge"

    def __init__(self, path: Path) -> None:
        self.path = path

    def sample(self, process_id: int) -> dict[str, Any]:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}
        if not isinstance(payload, dict):
            return {}
        payload_pid = int(payload.get("pid") or 0)
        if payload_pid not in (0, process_id):
            return {}
        return {
            "fps": _number(payload.get("fps")),
            "frame_time_ms": _number(payload.get("frame_time_ms")),
            "fps_1_percent_low": _number(payload.get("fps_1_percent_low")),
            "frame_stats_provider": str(payload.get("provider") or self.name),
        }


@dataclass(frozen=True)
class DetectedGame:
    game: GameDefinition
    executable: str
    pid: int
    started_at: Optional[float] = None

    def to_json(self) -> dict[str, Any]:
        return {
            "game_name": self.game.name,
            "executable": self.executable,
            "pid": self.pid,
            "started_at": self.started_at,
            "icon": self.game.icon,
            "genre": self.game.genre,
            "publisher": self.game.publisher,
            "steam_app_id": self.game.steam_app_id,
        }


@dataclass
class MetricAccumulator:
    include_zero: bool = True
    total: float = 0.0
    count: int = 0
    maximum: Optional[float] = None

    def add(self, value: Any) -> None:
        number = _number(value)
        if number is None:
            return
        if not self.include_zero and number <= 0:
            return

        self.total += number
        self.count += 1
        self.maximum = number if self.maximum is None else max(self.maximum, number)

    @property
    def average(self) -> Optional[float]:
        if self.count == 0:
            return None
        return self.total / self.count


@dataclass
class ActiveGamingSession:
    id: str
    game: GameDefinition
    executable: str
    started_at: datetime
    platform: str
    hardwaremon_version: str
    active_processes: list[dict[str, Any]] = field(default_factory=list)
    latest_sample: Optional[dict[str, Any]] = None
    total_samples: int = 0
    metrics: dict[str, MetricAccumulator] = field(
        default_factory=lambda: {
            "cpu_usage": MetricAccumulator(),
            "gpu_usage": MetricAccumulator(),
            "ram_usage": MetricAccumulator(),
            "cpu_temperature": MetricAccumulator(include_zero=False),
            "gpu_temperature": MetricAccumulator(include_zero=False),
            "cpu_clock": MetricAccumulator(include_zero=False),
            "gpu_power": MetricAccumulator(include_zero=False),
            "cpu_power": MetricAccumulator(include_zero=False),
        }
    )

    def add_sample(self, stats: dict[str, Any], sampled_at: datetime) -> None:
        sample = {
            "sampled_at": sampled_at.isoformat(),
            "cpu_usage": _number(stats.get("cpu")),
            "gpu_usage": _number(stats.get("gpu_usage")),
            "ram_usage": _number(stats.get("ram")),
            "cpu_temperature": _number(stats.get("cpu_temp")),
            "gpu_temperature": _number(stats.get("gpu_temp")),
            "cpu_clock": _number(stats.get("cpu_clock")),
            "gpu_power": _number(stats.get("gpu_power")),
            "cpu_power": _number(stats.get("cpu_power")),
            "fps": _number(stats.get("fps")),
            "frame_time_ms": _number(stats.get("frame_time_ms")),
            "fps_1_percent_low": _number(stats.get("fps_1_percent_low")),
            "frame_stats_provider": stats.get("frame_stats_provider"),
        }
        self.latest_sample = sample
        self.total_samples += 1
        for metric, accumulator in self.metrics.items():
            accumulator.add(sample.get(metric))

    def values(self, ended_at: Optional[datetime] = None) -> dict[str, Any]:
        now = ended_at or datetime.now(timezone.utc)
        duration_seconds = max(0.0, (now - self.started_at).total_seconds())
        cpu = self.metrics["cpu_usage"]
        gpu = self.metrics["gpu_usage"]
        ram = self.metrics["ram_usage"]
        cpu_temp = self.metrics["cpu_temperature"]
        gpu_temp = self.metrics["gpu_temperature"]
        cpu_clock = self.metrics["cpu_clock"]
        gpu_power = self.metrics["gpu_power"]
        cpu_power = self.metrics["cpu_power"]

        return {
            "id": self.id,
            "game_name": self.game.name,
            "executable": self.executable,
            "started_at": self.started_at.isoformat(),
            "ended_at": ended_at.isoformat() if ended_at else None,
            "duration_seconds": round(duration_seconds, 3),
            "platform": self.platform,
            "avg_cpu_usage": _round_or_none(cpu.average),
            "avg_gpu_usage": _round_or_none(gpu.average),
            "avg_ram_usage": _round_or_none(ram.average),
            "avg_cpu_temperature": _round_or_none(cpu_temp.average),
            "avg_gpu_temperature": _round_or_none(gpu_temp.average),
            "peak_cpu_temperature": _round_or_none(cpu_temp.maximum),
            "peak_gpu_temperature": _round_or_none(gpu_temp.maximum),
            "peak_ram_usage": _round_or_none(ram.maximum),
            "peak_gpu_usage": _round_or_none(gpu.maximum),
            "avg_cpu_clock": _round_or_none(cpu_clock.average),
            "avg_gpu_power": _round_or_none(gpu_power.average),
            "avg_cpu_power": _round_or_none(cpu_power.average),
            "max_cpu_usage": _round_or_none(cpu.maximum),
            "max_gpu_usage": _round_or_none(gpu.maximum),
            "total_samples": self.total_samples,
            "hardwaremon_version": self.hardwaremon_version,
            "status": "active" if ended_at is None else "completed",
            "game": self.game.to_json(),
            "active_processes": list(self.active_processes),
            "latest_sample": dict(self.latest_sample) if self.latest_sample else None,
            "gaming_mode_version": GAMING_MODE_VERSION,
        }


ProcessProvider = Callable[[], Iterable[dict[str, Any]]]
StatsCollector = Callable[[], dict[str, Any]]
ConnectionFactory = Callable[[], Any]


class GamingService:
    def __init__(
        self,
        *,
        poll_interval: float = 5.0,
        games_path: Optional[Path] = None,
        process_provider: Optional[ProcessProvider] = None,
        stats_collector: StatsCollector = collect_stats,
        connection_factory: ConnectionFactory = get_connection,
        hardwaremon_version: str = DEFAULT_HARDWAREMON_VERSION,
        frame_stats_provider: Optional[FrameStatsProvider] = None,
    ) -> None:
        self.poll_interval = max(1.0, poll_interval)
        self.games_path = games_path or Path(__file__).with_name("games.json")
        self._process_provider = process_provider or self._iter_processes
        self._stats_collector = stats_collector
        self._connection_factory = connection_factory
        self._hardwaremon_version = hardwaremon_version
        bridge_path = os.environ.get("HARDWAREMON_FRAME_STATS_PATH")
        self._frame_stats_provider = frame_stats_provider or (
            JsonFrameStatsProvider(Path(bridge_path)) if bridge_path else None
        )
        self._games = self._load_games()
        self._lock = threading.RLock()
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._current_session: Optional[ActiveGamingSession] = None
        self._last_event: Optional[dict[str, Any]] = None

    @property
    def games(self) -> list[dict[str, Any]]:
        return [game.to_json() for game in self._games]

    def start(self) -> None:
        with self._lock:
            if self._thread is not None and self._thread.is_alive():
                return
            self._close_interrupted_sessions()
            self._stop_event.clear()
            self._thread = threading.Thread(
                target=self._run,
                daemon=True,
                name="hardwaremon-gaming-detector",
            )
            self._thread.start()

    def stop(self, timeout: float = 2.0) -> None:
        self._stop_event.set()
        thread = self._thread
        if thread is not None:
            thread.join(timeout=timeout)

    def scan_once(self) -> None:
        detected = self.detect_games()
        session_id_to_sample: Optional[str] = None

        with self._lock:
            if detected:
                if self._current_session is None:
                    selected = detected[0]
                    self._current_session = ActiveGamingSession(
                        id=str(uuid.uuid4()),
                        game=selected.game,
                        executable=selected.executable,
                        started_at=datetime.now(timezone.utc),
                        platform=platform.platform(),
                        hardwaremon_version=self._hardwaremon_version,
                    )
                    self._current_session.active_processes = [
                        item.to_json() for item in detected
                    ]
                    self._insert_session(self._current_session)
                    self._record_event(
                        "started",
                        "Game detected",
                        f"{selected.game.name} gaming session started.",
                        self._current_session,
                    )
                else:
                    self._current_session.active_processes = [
                        item.to_json() for item in detected
                    ]
                session_id_to_sample = self._current_session.id
            elif self._current_session is not None:
                self._finish_current_session()

        if session_id_to_sample is None:
            return

        try:
            stats = self._stats_collector()
            if self._frame_stats_provider is not None and self._current_session is not None:
                process_id = int(self._current_session.active_processes[0].get("pid") or 0)
                stats.update(self._frame_stats_provider.sample(process_id))
        except Exception as error:
            stats = {"sample_error": str(error)}

        with self._lock:
            if (
                self._current_session is not None
                and self._current_session.id == session_id_to_sample
            ):
                self._current_session.add_sample(stats, datetime.now(timezone.utc))
                self._update_session(self._current_session)

    def detect_games(self) -> list[DetectedGame]:
        detected: list[DetectedGame] = []
        seen: set[tuple[str, int]] = set()

        for process in self._process_provider():
            for game in self._games:
                executable = self._matching_executable(game, process)
                if executable is None:
                    continue
                pid = int(process.get("pid") or 0)
                key = (game.name, pid)
                if key in seen:
                    continue
                seen.add(key)
                detected.append(
                    DetectedGame(
                        game=game,
                        executable=executable,
                        pid=pid,
                        started_at=_number(process.get("create_time")),
                    )
                )
                break

        detected.sort(key=lambda item: item.started_at or time.time())
        return detected

    def get_current(self) -> dict[str, Any]:
        with self._lock:
            session = (
                self._current_session.values()
                if self._current_session is not None
                else None
            )
            return {
                "active": session is not None,
                "session": session,
                "last_event": dict(self._last_event) if self._last_event else None,
                "known_games": len(self._games),
                "poll_interval_seconds": self.poll_interval,
                "overlay": self.overlay_capabilities(),
            }

    def overlay_capabilities(self) -> dict[str, Any]:
        system = platform.system().lower()
        desktop = system in {"windows", "linux", "darwin"}
        return {
            "platform": system,
            "desktop_overlay_supported": desktop,
            "global_hotkeys_supported": desktop,
            "frame_stats_available": self._frame_stats_provider is not None,
            "frame_stats_provider": getattr(self._frame_stats_provider, "name", None),
            "exclusive_fullscreen_supported": False,
            "mode": "always-on-top-window" if desktop else "dashboard-only",
            "reason": None if desktop else "System-wide overlays are not enabled on this platform.",
        }

    def list_sessions(self, limit: int = 50) -> list[dict[str, Any]]:
        conn = self._connection_factory()
        try:
            rows = conn.execute(
                """
                SELECT * FROM gaming_sessions
                WHERE ended_at IS NOT NULL
                ORDER BY started_at DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
            return [_row_to_session(row) for row in rows]
        finally:
            conn.close()

    def latest_session(self) -> Optional[dict[str, Any]]:
        conn = self._connection_factory()
        try:
            row = conn.execute(
                """
                SELECT * FROM gaming_sessions
                ORDER BY started_at DESC
                LIMIT 1
                """
            ).fetchone()
            return _row_to_session(row) if row is not None else None
        finally:
            conn.close()

    def get_session(self, session_id: str) -> Optional[dict[str, Any]]:
        with self._lock:
            if self._current_session is not None and self._current_session.id == session_id:
                return self._current_session.values()

        conn = self._connection_factory()
        try:
            row = conn.execute(
                "SELECT * FROM gaming_sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
            return _row_to_session(row) if row is not None else None
        finally:
            conn.close()

    def delete_session(self, session_id: str) -> bool:
        with self._lock:
            if self._current_session is not None and self._current_session.id == session_id:
                return False

        conn = self._connection_factory()
        try:
            cursor = conn.execute(
                "DELETE FROM gaming_sessions WHERE id = ?",
                (session_id,),
            )
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

    def statistics(self) -> dict[str, Any]:
        sessions = self.list_sessions(limit=10_000)
        completed = [item for item in sessions if item.get("total_samples", 0) > 0]
        total_sessions = len(sessions)
        total_seconds = sum(float(item.get("duration_seconds") or 0) for item in sessions)
        games = {item["game_name"] for item in sessions}

        grouped: dict[str, dict[str, Any]] = {}
        for item in sessions:
            bucket = grouped.setdefault(
                item["game_name"],
                {"game_name": item["game_name"], "sessions": 0, "duration_seconds": 0.0},
            )
            bucket["sessions"] += 1
            bucket["duration_seconds"] += float(item.get("duration_seconds") or 0)

        most_played = (
            max(grouped.values(), key=lambda item: item["duration_seconds"])
            if grouped
            else None
        )
        longest = (
            max(sessions, key=lambda item: float(item.get("duration_seconds") or 0))
            if sessions
            else None
        )

        def hottest_value(item: dict[str, Any]) -> float:
            return max(
                float(item.get("peak_cpu_temperature") or 0),
                float(item.get("peak_gpu_temperature") or 0),
            )

        hottest = max(completed, key=hottest_value) if completed else None

        return {
            "total_sessions": total_sessions,
            "total_gaming_seconds": round(total_seconds, 3),
            "total_gaming_hours": round(total_seconds / 3600, 2),
            "average_session_seconds": round(total_seconds / total_sessions, 3)
            if total_sessions
            else 0,
            "most_played_game": most_played,
            "longest_session": longest,
            "hottest_recorded_session": hottest,
            "average_cpu_temperature": _average_session_value(
                completed, "avg_cpu_temperature"
            ),
            "average_gpu_temperature": _average_session_value(
                completed, "avg_gpu_temperature"
            ),
            "games_played": len(games),
            "largest_gpu_usage": _max_session_value(completed, "max_gpu_usage"),
            "largest_cpu_usage": _max_session_value(completed, "max_cpu_usage"),
            "known_games": len(self._games),
        }

    def _run(self) -> None:
        while not self._stop_event.is_set():
            try:
                self.scan_once()
            except Exception as error:
                print(f"Gaming detector error: {error}")
            self._stop_event.wait(self.poll_interval)

    def _load_games(self) -> list[GameDefinition]:
        try:
            payload = json.loads(self.games_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            payload = []

        games = [
            GameDefinition.from_json(item)
            for item in payload
            if isinstance(item, dict)
        ]
        return [game for game in games if game.executables]

    def _matching_executable(
        self,
        game: GameDefinition,
        process: dict[str, Any],
    ) -> Optional[str]:
        name = _basename(process.get("name")).lower()
        exe = _basename(process.get("exe")).lower()
        cmdline = process.get("cmdline") or []
        if isinstance(cmdline, str):
            cmdline_text = cmdline
        else:
            cmdline_text = " ".join(str(item) for item in cmdline)
        search_blob = " ".join([name, exe, cmdline_text]).lower()

        if game.process_keywords and not any(
            keyword in search_blob for keyword in game.process_keywords
        ):
            return None

        for executable in game.executables:
            candidate = executable.lower()
            candidate_stem = _stem(candidate)
            if (
                name == candidate
                or exe == candidate
                or _stem(name) == candidate_stem
                or _stem(exe) == candidate_stem
                or ("." not in candidate and (candidate in name or candidate in exe))
            ):
                return _basename(process.get("name")) or executable
        return None

    def _iter_processes(self) -> Iterable[dict[str, Any]]:
        for proc in psutil.process_iter(["pid", "name", "exe", "cmdline", "create_time"]):
            try:
                yield dict(proc.info)
            except (psutil.AccessDenied, psutil.NoSuchProcess, psutil.ZombieProcess):
                continue

    def _insert_session(self, session: ActiveGamingSession) -> None:
        values = session.values()
        conn = self._connection_factory()
        try:
            conn.execute(
                """
                INSERT INTO gaming_sessions (
                    id, game_name, executable, started_at, ended_at,
                    duration_seconds, platform, avg_cpu_usage, avg_gpu_usage,
                    avg_ram_usage, avg_cpu_temperature, avg_gpu_temperature,
                    peak_cpu_temperature, peak_gpu_temperature, peak_ram_usage,
                    peak_gpu_usage, avg_cpu_clock, avg_gpu_power, avg_cpu_power,
                    max_cpu_usage, max_gpu_usage, total_samples,
                    hardwaremon_version, status, raw_session_json, updated_at
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?
                )
                """,
                _session_row_values(values),
            )
            conn.commit()
        finally:
            conn.close()

    def _update_session(
        self,
        session: ActiveGamingSession,
        *,
        ended_at: Optional[datetime] = None,
        status: str = "active",
    ) -> None:
        values = session.values(ended_at=ended_at)
        values["status"] = status
        conn = self._connection_factory()
        try:
            conn.execute(
                """
                UPDATE gaming_sessions
                SET
                    game_name = ?,
                    executable = ?,
                    started_at = ?,
                    ended_at = ?,
                    duration_seconds = ?,
                    platform = ?,
                    avg_cpu_usage = ?,
                    avg_gpu_usage = ?,
                    avg_ram_usage = ?,
                    avg_cpu_temperature = ?,
                    avg_gpu_temperature = ?,
                    peak_cpu_temperature = ?,
                    peak_gpu_temperature = ?,
                    peak_ram_usage = ?,
                    peak_gpu_usage = ?,
                    avg_cpu_clock = ?,
                    avg_gpu_power = ?,
                    avg_cpu_power = ?,
                    max_cpu_usage = ?,
                    max_gpu_usage = ?,
                    total_samples = ?,
                    hardwaremon_version = ?,
                    status = ?,
                    raw_session_json = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (*_session_update_values(values), session.id),
            )
            conn.commit()
        finally:
            conn.close()

    def _finish_current_session(self) -> None:
        session = self._current_session
        if session is None:
            return
        ended_at = datetime.now(timezone.utc)
        session.active_processes = []
        self._update_session(session, ended_at=ended_at, status="completed")
        self._record_event(
            "completed",
            "Session completed",
            _completion_body(session.values(ended_at=ended_at)),
            session,
        )
        self._current_session = None

    def _record_event(
        self,
        event_type: str,
        title: str,
        body: str,
        session: ActiveGamingSession,
    ) -> None:
        now = datetime.now(timezone.utc)
        self._last_event = {
            "id": f"{session.id}:{event_type}:{int(now.timestamp() * 1000)}",
            "type": event_type,
            "title": title,
            "body": body,
            "session_id": session.id,
            "game_name": session.game.name,
            "timestamp": now.isoformat(),
        }

    def _close_interrupted_sessions(self) -> None:
        conn = self._connection_factory()
        try:
            rows = conn.execute(
                "SELECT id, started_at FROM gaming_sessions WHERE status = 'active'"
            ).fetchall()
            now = datetime.now(timezone.utc)
            for row in rows:
                started = _parse_datetime(row["started_at"]) or now
                duration = max(0.0, (now - started).total_seconds())
                conn.execute(
                    """
                    UPDATE gaming_sessions
                    SET ended_at = ?, duration_seconds = ?, status = 'interrupted',
                        updated_at = ?
                    WHERE id = ?
                    """,
                    (now.isoformat(), round(duration, 3), now.isoformat(), row["id"]),
                )
            conn.commit()
        finally:
            conn.close()


def _session_row_values(values: dict[str, Any]) -> tuple[Any, ...]:
    return (
        values["id"],
        values["game_name"],
        values["executable"],
        values["started_at"],
        values["ended_at"],
        values["duration_seconds"],
        values["platform"],
        values["avg_cpu_usage"],
        values["avg_gpu_usage"],
        values["avg_ram_usage"],
        values["avg_cpu_temperature"],
        values["avg_gpu_temperature"],
        values["peak_cpu_temperature"],
        values["peak_gpu_temperature"],
        values["peak_ram_usage"],
        values["peak_gpu_usage"],
        values["avg_cpu_clock"],
        values["avg_gpu_power"],
        values["avg_cpu_power"],
        values["max_cpu_usage"],
        values["max_gpu_usage"],
        values["total_samples"],
        values["hardwaremon_version"],
        values["status"],
        _raw_json(values),
        datetime.now(timezone.utc).isoformat(),
    )


def _session_update_values(values: dict[str, Any]) -> tuple[Any, ...]:
    return (
        values["game_name"],
        values["executable"],
        values["started_at"],
        values["ended_at"],
        values["duration_seconds"],
        values["platform"],
        values["avg_cpu_usage"],
        values["avg_gpu_usage"],
        values["avg_ram_usage"],
        values["avg_cpu_temperature"],
        values["avg_gpu_temperature"],
        values["peak_cpu_temperature"],
        values["peak_gpu_temperature"],
        values["peak_ram_usage"],
        values["peak_gpu_usage"],
        values["avg_cpu_clock"],
        values["avg_gpu_power"],
        values["avg_cpu_power"],
        values["max_cpu_usage"],
        values["max_gpu_usage"],
        values["total_samples"],
        values["hardwaremon_version"],
        values["status"],
        _raw_json(values),
        datetime.now(timezone.utc).isoformat(),
    )


def _row_to_session(row: Any) -> dict[str, Any]:
    result = dict(row)
    raw = result.pop("raw_session_json", "{}")
    try:
        raw_payload = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        raw_payload = {}
    result["game"] = raw_payload.get("game")
    result["active_processes"] = raw_payload.get("active_processes", [])
    result["latest_sample"] = raw_payload.get("latest_sample")
    result["gaming_mode_version"] = raw_payload.get(
        "gaming_mode_version",
        GAMING_MODE_VERSION,
    )
    return result


def _raw_json(values: dict[str, Any]) -> str:
    payload = {
        "game": values.get("game"),
        "active_processes": values.get("active_processes", []),
        "latest_sample": values.get("latest_sample"),
        "gaming_mode_version": values.get("gaming_mode_version", GAMING_MODE_VERSION),
    }
    return json.dumps(payload, separators=(",", ":"))


def _average_session_value(sessions: list[dict[str, Any]], key: str) -> Optional[float]:
    values = [float(item[key]) for item in sessions if item.get(key) is not None]
    if not values:
        return None
    return round(sum(values) / len(values), 2)


def _max_session_value(sessions: list[dict[str, Any]], key: str) -> Optional[float]:
    values = [float(item[key]) for item in sessions if item.get(key) is not None]
    if not values:
        return None
    return round(max(values), 2)


def _completion_body(values: dict[str, Any]) -> str:
    duration = _format_duration(values.get("duration_seconds") or 0)
    gpu_temp = values.get("avg_gpu_temperature")
    if gpu_temp is None:
        return f"{duration} recorded with {values.get('total_samples', 0)} samples."
    return f"{duration} · Average GPU Temp {float(gpu_temp):.0f}C."


def _format_duration(seconds: Any) -> str:
    total = max(0, int(float(seconds)))
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"{hours}h {minutes}m"
    if minutes:
        return f"{minutes}m {seconds}s"
    return f"{seconds}s"


def _parse_datetime(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    text = str(value)
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _basename(value: Any) -> str:
    text = str(value or "").strip().replace("\\", "/")
    return text.rsplit("/", 1)[-1]


def _stem(value: str) -> str:
    return value[:-4] if value.endswith(".exe") else value


def _number(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number


def _round_or_none(value: Optional[float]) -> Optional[float]:
    if value is None:
        return None
    return round(value, 2)


def _optional_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
