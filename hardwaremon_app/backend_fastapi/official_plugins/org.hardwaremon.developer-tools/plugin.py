from __future__ import annotations

import json
import os
import sys
import time


token = os.environ["HARDWAREMON_PLUGIN_TOKEN"]


def send(kind: str, **payload) -> None:
    print(json.dumps({"type": kind, "token": token, **payload}), flush=True)


send("plugin.ready")
send("plugin.log", level="info", message="Protocol handshake complete")
samples = 0
last_heartbeat = time.monotonic()
for line in sys.stdin:
    try:
        message = json.loads(line)
    except json.JSONDecodeError:
        continue
    if message.get("token") != token:
        continue
    if message.get("type") == "host.shutdown":
        break
    if message.get("type") == "telemetry.sample":
        samples += 1
        if samples % 30 == 0:
            send("plugin.log", level="debug", message=f"Received {samples} telemetry samples")
    if time.monotonic() - last_heartbeat >= 5:
        send("plugin.heartbeat")
        last_heartbeat = time.monotonic()
