import platform
import time

import psutil
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ── Initialise net baseline ───────────────────────────────────────────────────
_last_net  = psutil.net_io_counters()
_last_time = time.time()

# ── CPU name (read once at startup, not every request) ───────────────────────
def _read_cpu_name() -> str:
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return platform.processor() or "Unknown CPU"

_CPU_NAME = _read_cpu_name()

# ── GPU helper (optional dependency) ─────────────────────────────────────────
def _gpu_info() -> dict:
    """Return gpu_name, gpu_usage, gpu_temp. Never raises."""
    try:
        import GPUtil  # optional – may not be installed / no NVIDIA
        gpus = GPUtil.getGPUs()
        if gpus:
            g = gpus[0]
            return {
                "gpu_name":  g.name,
                "gpu_usage": int(g.load * 100),
                "gpu_temp":  int(g.temperature),
            }
    except Exception:
        pass
    return {"gpu_name": "No GPU", "gpu_usage": 0, "gpu_temp": 0}


@app.route("/stats")
def stats():
    global _last_net, _last_time

    # ── Network speeds ────────────────────────────────────────────────────
    current_net  = psutil.net_io_counters()
    current_time = time.time()
    elapsed      = max(current_time - _last_time, 0.001)  # avoid div-by-zero

    upload_speed   = (current_net.bytes_sent - _last_net.bytes_sent) / 1024 / elapsed
    download_speed = (current_net.bytes_recv - _last_net.bytes_recv) / 1024 / elapsed

    _last_net  = current_net
    _last_time = current_time

    core_percents = psutil.cpu_percent(interval=0.1, percpu=True)
    cpu_overall   = round(sum(core_percents) / len(core_percents)) if core_percents else 0

    # ── Memory / disk ─────────────────────────────────────────────────────
    vm        = psutil.virtual_memory()
    ram_pct   = int(vm.percent)
    ram_total = round(vm.total / (1024 ** 3))
    disk_pct  = int(psutil.disk_usage("/").percent)

    data = {
        "cpu":      cpu_overall,
        "cores":    [int(x) for x in core_percents],

        "ram":       ram_pct,
        "ram_total": ram_total,

        "disk": disk_pct,

        "upload":   round(upload_speed,   1),
        "download": round(download_speed, 1),

        "cpu_name": _CPU_NAME,
        **_gpu_info(),   # gpu_name, gpu_usage, gpu_temp
    }

    return jsonify(data)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)