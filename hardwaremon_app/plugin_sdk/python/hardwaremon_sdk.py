"""Dependency-free HardwareMon Plugin API v1 client.

Copy this file into a plugin package. It intentionally uses only the standard
library so plugins do not inherit dependencies from the HardwareMon backend.
"""

from __future__ import annotations

import json
import os
import sys
import threading
import time
from collections.abc import Callable
from typing import Any


class HardwareMonPlugin:
    def __init__(self) -> None:
        self.plugin_id = os.environ["HARDWAREMON_PLUGIN_ID"]
        self.token = os.environ["HARDWAREMON_PLUGIN_TOKEN"]
        self.api_version = int(os.environ["HARDWAREMON_PLUGIN_API"])
        self.grants: frozenset[str] = frozenset()
        self.running = True
        self._handlers: dict[str, list[Callable[[dict[str, Any]], None]]] = {}
        self._write_lock = threading.Lock()

    def on(self, message_type: str, handler: Callable[[dict[str, Any]], None]) -> None:
        self._handlers.setdefault(message_type, []).append(handler)

    def log(self, message: str, level: str = "info") -> None:
        self._send("plugin.log", level=level, message=message)

    def publish_event(self, message: str, **fields: Any) -> None:
        if "events.publish" not in self.grants:
            raise PermissionError("events.publish was not granted")
        self._send("plugin.event", message=message, fields=fields)

    def run(self) -> None:
        last_heartbeat = 0.0
        for line in sys.stdin:
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("token") != self.token:
                continue
            kind = str(message.get("type", ""))
            if kind == "host.hello":
                self.grants = frozenset(map(str, message.get("grants", [])))
                self._send("plugin.ready")
            elif kind == "host.shutdown":
                self.running = False
                break
            for handler in self._handlers.get(kind, []):
                handler(message)
            if time.monotonic() - last_heartbeat >= 5:
                self._send("plugin.heartbeat")
                last_heartbeat = time.monotonic()

    def _send(self, message_type: str, **payload: Any) -> None:
        value = {"type": message_type, "token": self.token, **payload}
        with self._write_lock:
            print(json.dumps(value, separators=(",", ":")), flush=True)
