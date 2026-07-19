from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time
import tempfile
import zipfile
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from database.database import get_data_dir
from telemetry.system import collect_stats


PLUGIN_API_VERSION = 1
PLUGIN_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{2,79}$")
KNOWN_CAPABILITIES = {
    "telemetry.read",
    "inventory.read",
    "history.read",
    "events.publish",
    "network.listen",
    "network.connect",
    "settings.read",
}


class PluginError(RuntimeError):
    pass


@dataclass
class PluginRuntime:
    plugin_id: str
    process: subprocess.Popen[str]
    token: str
    started_at: float
    last_heartbeat: float
    status: str = "starting"
    restart_count: int = 0
    logs: deque[dict[str, Any]] = field(default_factory=lambda: deque(maxlen=300))
    writer_lock: threading.Lock = field(default_factory=threading.Lock)


class PluginBroker:
    """Supervises capability-scoped plugin processes.

    Plugins never import into the HardwareMon process. The broker validates
    manifests and paths, launches a minimal environment, authenticates every
    protocol message with a per-launch token, and filters host data by grant.
    """

    def __init__(
        self,
        poll_seconds: float = 2.0,
        data_dir: Path | None = None,
        bundled_root: Path | None = None,
    ):
        self.poll_seconds = poll_seconds
        self.data_dir = data_dir or get_data_dir()
        self.root = self.data_dir / "plugins"
        self.registry_path = self.data_dir / "plugin-registry.json"
        self.bundled_root = bundled_root or (
            Path(__file__).resolve().parent.parent / "official_plugins"
        )
        self._lock = threading.RLock()
        self._runtimes: dict[str, PluginRuntime] = {}
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._registry = self._load_registry()

    def start(self) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        self.install_bundled_plugins()
        with self._lock:
            if self._thread and self._thread.is_alive():
                return
            self._stop.clear()
            self._thread = threading.Thread(
                target=self._monitor_loop,
                daemon=True,
                name="hardwaremon-plugin-broker",
            )
            self._thread.start()
        for plugin in self.list_plugins():
            if plugin["enabled"] and plugin["approved"]:
                try:
                    self.launch(plugin["id"])
                except PluginError as exc:
                    self._record_system_log(plugin["id"], "error", str(exc))

    def stop(self) -> None:
        self._stop.set()
        with self._lock:
            plugin_ids = list(self._runtimes)
        for plugin_id in plugin_ids:
            self.stop_plugin(plugin_id)
        thread = self._thread
        if thread and thread is not threading.current_thread():
            thread.join(timeout=3)

    def install_bundled_plugins(self) -> None:
        bundled = self.bundled_root
        if not bundled.exists():
            return
        for source in bundled.iterdir():
            if not source.is_dir() or not (source / "hardwaremon-plugin.json").exists():
                continue
            target = self.root / source.name
            if not target.exists():
                shutil.copytree(source, target)
            state = self._registry.setdefault(source.name, {})
            state["bundled"] = True
            state.setdefault("enabled", False)
            state.setdefault("grants", [])
        self._save_registry()

    def list_plugins(self) -> list[dict[str, Any]]:
        self.root.mkdir(parents=True, exist_ok=True)
        result = []
        for directory in sorted(self.root.iterdir()):
            if not directory.is_dir():
                continue
            try:
                manifest = self._read_manifest(directory)
            except PluginError as exc:
                result.append({
                    "id": directory.name,
                    "name": directory.name,
                    "version": "unknown",
                    "valid": False,
                    "error": str(exc),
                    "enabled": False,
                    "approved": False,
                    "status": "invalid",
                    "capabilities": [],
                    "granted_capabilities": [],
                })
                continue
            state = self._registry.get(manifest["id"], {})
            manifest["official"] = bool(state.get("bundled", False))
            runtime = self._runtimes.get(manifest["id"])
            requested = manifest["capabilities"]
            granted = [value for value in state.get("grants", []) if value in requested]
            result.append({
                **manifest,
                "valid": True,
                "enabled": bool(state.get("enabled", False)),
                "approved": set(requested).issubset(granted),
                "granted_capabilities": granted,
                "status": runtime.status if runtime else "stopped",
                "pid": runtime.process.pid if runtime else None,
                "started_at": runtime.started_at if runtime else None,
                "last_heartbeat": runtime.last_heartbeat if runtime else None,
                "restart_count": int(state.get("restart_count", 0)),
            })
        return result

    def plugin_details(self, plugin_id: str) -> dict[str, Any]:
        plugin = next((item for item in self.list_plugins() if item["id"] == plugin_id), None)
        if not plugin:
            raise PluginError("Plugin was not found")
        plugin["logs"] = self.logs(plugin_id)
        return plugin

    def set_grants(self, plugin_id: str, grants: list[str]) -> dict[str, Any]:
        manifest = self._manifest_for(plugin_id)
        unknown = set(grants) - KNOWN_CAPABILITIES
        unrequested = set(grants) - set(manifest["capabilities"])
        if unknown:
            raise PluginError(f"Unknown capabilities: {', '.join(sorted(unknown))}")
        if unrequested:
            raise PluginError(f"Plugin did not request: {', '.join(sorted(unrequested))}")
        self.stop_plugin(plugin_id)
        state = self._registry.setdefault(plugin_id, {})
        state["grants"] = sorted(set(grants))
        state["enabled"] = False
        self._save_registry()
        return self.plugin_details(plugin_id)

    def set_enabled(self, plugin_id: str, enabled: bool) -> dict[str, Any]:
        manifest = self._manifest_for(plugin_id)
        state = self._registry.setdefault(plugin_id, {})
        granted = set(state.get("grants", []))
        if enabled and not set(manifest["capabilities"]).issubset(granted):
            raise PluginError("Approve every requested capability before enabling this plugin")
        state["enabled"] = enabled
        if enabled:
            state["restart_count"] = 0
        self._save_registry()
        if enabled:
            self.launch(plugin_id)
        else:
            self.stop_plugin(plugin_id)
        return self.plugin_details(plugin_id)

    def install_archive(self, payload: bytes) -> dict[str, Any]:
        if not payload or len(payload) > 25 * 1024 * 1024:
            raise PluginError("Plugin archive must be between 1 byte and 25 MB")
        self.root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="hardwaremon-plugin-") as temporary:
            archive_path = Path(temporary) / "plugin.hmp"
            archive_path.write_bytes(payload)
            staging = Path(temporary) / "content"
            staging.mkdir()
            try:
                with zipfile.ZipFile(archive_path) as archive:
                    members = archive.infolist()
                    if len(members) > 500:
                        raise PluginError("Plugin archive contains too many files")
                    total = 0
                    for member in members:
                        total += member.file_size
                        if total > 100 * 1024 * 1024:
                            raise PluginError("Expanded plugin is larger than 100 MB")
                        relative = Path(member.filename)
                        if relative.is_absolute() or ".." in relative.parts:
                            raise PluginError("Plugin archive contains an unsafe path")
                        if member.external_attr >> 16 & 0o170000 == 0o120000:
                            raise PluginError("Plugin archives cannot contain symbolic links")
                    archive.extractall(staging)
            except zipfile.BadZipFile as exc:
                raise PluginError("Plugin package is not a valid .hmp archive") from exc
            manifests = list(staging.rglob("hardwaremon-plugin.json"))
            if len(manifests) != 1:
                raise PluginError("Plugin package must contain exactly one manifest")
            source = manifests[0].parent
            manifest = self._read_manifest(source)
            target = self.root / manifest["id"]
            if target.exists():
                state = self._registry.get(manifest["id"], {})
                if state.get("enabled"):
                    raise PluginError("Disable the installed plugin before updating it")
            staged_target = self.root / f".{manifest['id']}.staging-{secrets.token_hex(5)}"
            backup = self.root / f".{manifest['id']}.backup-{secrets.token_hex(5)}"
            shutil.copytree(source, staged_target)
            # Staging has a generated directory name, so validate content and
            # entrypoint before the atomic directory swap, then validate the
            # id-to-directory invariant at the final path.
            if target.exists():
                target.replace(backup)
            try:
                staged_target.replace(target)
                installed = self._read_manifest(target)
            except Exception:
                if target.exists():
                    shutil.rmtree(target)
                if backup.exists():
                    backup.replace(target)
                raise
            finally:
                if staged_target.exists():
                    shutil.rmtree(staged_target)
            if backup.exists():
                shutil.rmtree(backup)
            state = self._registry.setdefault(installed["id"], {
                "enabled": False,
                "grants": [],
                "restart_count": 0,
            })
            state["bundled"] = False
            self._save_registry()
            return self.plugin_details(installed["id"])

    def remove_plugin(self, plugin_id: str) -> None:
        self._manifest_for(plugin_id)
        if self._registry.get(plugin_id, {}).get("bundled"):
            raise PluginError("Bundled official plugins cannot be removed")
        state = self._registry.get(plugin_id, {})
        if state.get("enabled"):
            raise PluginError("Disable the plugin before removing it")
        target = (self.root / plugin_id).resolve()
        if target.parent != self.root.resolve():
            raise PluginError("Plugin path escapes the plugin root")
        shutil.rmtree(target)
        self._registry.pop(plugin_id, None)
        self._save_registry()

    def launch(self, plugin_id: str) -> None:
        with self._lock:
            existing = self._runtimes.get(plugin_id)
            if existing and existing.process.poll() is None:
                return
        manifest = self._manifest_for(plugin_id)
        state = self._registry.get(plugin_id, {})
        if not state.get("enabled"):
            raise PluginError("Plugin is disabled")
        if not set(manifest["capabilities"]).issubset(state.get("grants", [])):
            raise PluginError("Plugin capabilities are not fully approved")
        directory = self.root / plugin_id
        command = self._command(directory, manifest["entrypoint"])
        token = secrets.token_urlsafe(32)
        env = {
            "PATH": os.environ.get("PATH", ""),
            "SYSTEMROOT": os.environ.get("SYSTEMROOT", ""),
            "WINDIR": os.environ.get("WINDIR", ""),
            "HOME": str(directory),
            "HARDWAREMON_PLUGIN_ID": plugin_id,
            "HARDWAREMON_PLUGIN_TOKEN": token,
            "HARDWAREMON_PLUGIN_API": str(PLUGIN_API_VERSION),
        }
        try:
            process = subprocess.Popen(
                command,
                cwd=directory,
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
            )
        except OSError as exc:
            raise PluginError(f"Could not launch plugin: {exc}") from exc
        runtime = PluginRuntime(plugin_id, process, token, time.time(), time.time())
        with self._lock:
            self._runtimes[plugin_id] = runtime
        threading.Thread(target=self._read_stdout, args=(runtime,), daemon=True).start()
        threading.Thread(target=self._read_stderr, args=(runtime,), daemon=True).start()
        self._send(runtime, {
            "type": "host.hello",
            "api": PLUGIN_API_VERSION,
            "token": token,
            "plugin_id": plugin_id,
            "grants": state.get("grants", []),
        })

    def stop_plugin(self, plugin_id: str) -> None:
        with self._lock:
            runtime = self._runtimes.pop(plugin_id, None)
        if not runtime:
            return
        try:
            self._send(runtime, {"type": "host.shutdown", "token": runtime.token})
            runtime.process.wait(timeout=2)
        except (subprocess.TimeoutExpired, OSError, BrokenPipeError):
            runtime.process.kill()
            runtime.process.wait(timeout=2)
        finally:
            for stream in (
                runtime.process.stdin,
                runtime.process.stdout,
                runtime.process.stderr,
            ):
                if stream:
                    stream.close()
        runtime.status = "stopped"

    def logs(self, plugin_id: str) -> list[dict[str, Any]]:
        with self._lock:
            runtime = self._runtimes.get(plugin_id)
            return list(runtime.logs) if runtime else list(
                self._registry.get(plugin_id, {}).get("recent_logs", [])
            )

    def _monitor_loop(self) -> None:
        while not self._stop.wait(self.poll_seconds):
            telemetry = None
            with self._lock:
                runtimes = list(self._runtimes.values())
            for runtime in runtimes:
                code = runtime.process.poll()
                if code is not None:
                    self._handle_exit(runtime, code)
                    continue
                state = self._registry.get(runtime.plugin_id, {})
                if "telemetry.read" in state.get("grants", []):
                    if telemetry is None:
                        try:
                            telemetry = collect_stats()
                        except Exception as exc:  # telemetry must not kill broker
                            telemetry = {"error": str(exc)}
                    try:
                        self._send(runtime, {
                            "type": "telemetry.sample",
                            "token": runtime.token,
                            "captured_at": time.time(),
                            "payload": telemetry,
                        })
                    except (OSError, BrokenPipeError):
                        pass
                if time.time() - runtime.last_heartbeat > 30:
                    runtime.status = "unresponsive"

    def _handle_exit(self, runtime: PluginRuntime, code: int) -> None:
        with self._lock:
            current = self._runtimes.get(runtime.plugin_id)
            if current is not runtime:
                return
            self._runtimes.pop(runtime.plugin_id, None)
        self._record_system_log(runtime.plugin_id, "error", f"Plugin exited with code {code}")
        state = self._registry.get(runtime.plugin_id, {})
        if state.get("enabled") and not self._stop.is_set():
            restarts = int(state.get("restart_count", 0)) + 1
            state["restart_count"] = restarts
            self._save_registry()
            if restarts <= 5:
                time.sleep(min(10, restarts * 2))
                try:
                    self.launch(runtime.plugin_id)
                except PluginError:
                    pass

    def _read_stdout(self, runtime: PluginRuntime) -> None:
        assert runtime.process.stdout is not None
        for line in runtime.process.stdout:
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                self._append_log(runtime, "warning", f"Invalid protocol output: {line.strip()}")
                continue
            if message.get("token") != runtime.token:
                self._append_log(runtime, "warning", "Rejected unauthenticated plugin message")
                continue
            kind = message.get("type")
            if kind in {"plugin.ready", "plugin.heartbeat"}:
                runtime.status = "running"
                runtime.last_heartbeat = time.time()
            elif kind == "plugin.log":
                self._append_log(runtime, str(message.get("level", "info")), str(message.get("message", "")))
            elif kind == "plugin.event":
                grants = self._registry.get(runtime.plugin_id, {}).get("grants", [])
                if "events.publish" in grants:
                    self._append_log(runtime, "event", str(message.get("message", "Plugin event")))

    def _read_stderr(self, runtime: PluginRuntime) -> None:
        assert runtime.process.stderr is not None
        for line in runtime.process.stderr:
            self._append_log(runtime, "stderr", line.rstrip())

    def _send(self, runtime: PluginRuntime, message: dict[str, Any]) -> None:
        if not runtime.process.stdin:
            raise BrokenPipeError
        with runtime.writer_lock:
            runtime.process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            runtime.process.stdin.flush()

    def _append_log(self, runtime: PluginRuntime, level: str, message: str) -> None:
        runtime.logs.append({"timestamp": time.time(), "level": level, "message": message[:2000]})
        state = self._registry.setdefault(runtime.plugin_id, {})
        state["recent_logs"] = list(runtime.logs)[-50:]

    def _record_system_log(self, plugin_id: str, level: str, message: str) -> None:
        state = self._registry.setdefault(plugin_id, {})
        logs = list(state.get("recent_logs", []))
        logs.append({"timestamp": time.time(), "level": level, "message": message})
        state["recent_logs"] = logs[-50:]
        self._save_registry()

    def _manifest_for(self, plugin_id: str) -> dict[str, Any]:
        if not PLUGIN_ID.fullmatch(plugin_id):
            raise PluginError("Invalid plugin identifier")
        directory = (self.root / plugin_id).resolve()
        if directory.parent != self.root.resolve():
            raise PluginError("Plugin path escapes the plugin root")
        return self._read_manifest(directory)

    def _read_manifest(self, directory: Path) -> dict[str, Any]:
        path = directory / "hardwaremon-plugin.json"
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise PluginError(f"Invalid or missing manifest: {exc}") from exc
        plugin_id = str(raw.get("id", ""))
        if not PLUGIN_ID.fullmatch(plugin_id) or directory.name != plugin_id:
            raise PluginError("Manifest id must match its directory name")
        if raw.get("api_version") != PLUGIN_API_VERSION:
            raise PluginError(f"Unsupported plugin API version; expected {PLUGIN_API_VERSION}")
        capabilities = sorted(set(map(str, raw.get("capabilities", []))))
        unknown = set(capabilities) - KNOWN_CAPABILITIES
        if unknown:
            raise PluginError(f"Unknown capabilities: {', '.join(sorted(unknown))}")
        entrypoint = raw.get("entrypoint")
        if not isinstance(entrypoint, dict):
            raise PluginError("Manifest entrypoint is required")
        entrypoint_type = entrypoint.get("type")
        if entrypoint_type not in {"python", "executable"}:
            raise PluginError("Entrypoint type must be python or executable")
        target = (directory / Path(str(entrypoint.get("path", "")))).resolve()
        if directory.resolve() not in target.parents or not target.is_file():
            raise PluginError("Entrypoint is missing or escapes the plugin directory")
        return {
            "id": plugin_id,
            "name": str(raw.get("name") or plugin_id),
            "version": str(raw.get("version") or "0.0.0"),
            "publisher": str(raw.get("publisher") or "Unknown publisher"),
            "description": str(raw.get("description") or ""),
            "homepage": str(raw.get("homepage") or ""),
            "official": False,
            "api_version": PLUGIN_API_VERSION,
            "capabilities": capabilities,
            "entrypoint": entrypoint,
        }

    def _command(self, directory: Path, entrypoint: dict[str, Any]) -> list[str]:
        kind = entrypoint.get("type")
        relative = Path(str(entrypoint.get("path", "")))
        target = (directory / relative).resolve()
        if directory.resolve() not in target.parents or not target.is_file():
            raise PluginError("Entrypoint is missing or escapes the plugin directory")
        if kind == "python":
            if getattr(sys, "frozen", False):
                return [sys.executable, "--plugin-runner", str(target)]
            return [sys.executable, "-I", str(target)]
        if kind == "executable":
            return [str(target)]
        raise PluginError("Entrypoint type must be python or executable")

    def _load_registry(self) -> dict[str, dict[str, Any]]:
        try:
            value = json.loads(self.registry_path.read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except (OSError, json.JSONDecodeError):
            return {}

    def _save_registry(self) -> None:
        with self._lock:
            self.registry_path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.registry_path.with_suffix(".tmp")
            temporary.write_text(json.dumps(self._registry, indent=2), encoding="utf-8")
            temporary.replace(self.registry_path)
