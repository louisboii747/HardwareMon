from __future__ import annotations

import json
import os
import queue
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


TOKEN = os.environ["HARDWAREMON_PLUGIN_TOKEN"]
samples: dict[str, object] = {}
commands: queue.Queue[dict] = queue.Queue()


def send(kind: str, **values) -> None:
    print(json.dumps({"type": kind, "token": TOKEN, **values}), flush=True)


def metric_name(value: str) -> str:
    return "hardwaremon_" + "".join(char if char.isalnum() else "_" for char in value.lower())


def render_metrics() -> bytes:
    lines = ["# HardwareMon Prometheus Exporter"]
    for key, value in sorted(samples.items()):
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            name = metric_name(key)
            lines.extend([f"# TYPE {name} gauge", f"{name} {value}"])
    return ("\n".join(lines) + "\n").encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_error(404)
            return
        body = render_metrics()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


def read_host() -> None:
    for line in sys.stdin:
        try:
            commands.put(json.loads(line))
        except json.JSONDecodeError:
            continue


threading.Thread(target=read_host, daemon=True).start()
server = ThreadingHTTPServer(("127.0.0.1", 9779), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
send("plugin.ready")
send("plugin.log", level="info", message="Prometheus metrics available at http://127.0.0.1:9779/metrics")

running = True
while running:
    try:
        message = commands.get(timeout=5)
        if message.get("token") != TOKEN:
            continue
        if message.get("type") == "telemetry.sample":
            samples = dict(message.get("payload") or {})
        elif message.get("type") == "host.shutdown":
            running = False
    except queue.Empty:
        pass
    send("plugin.heartbeat")

server.shutdown()
