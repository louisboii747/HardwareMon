import platform
import psutil
from flask import Flask, jsonify, request
from flask_cors import CORS
import signal
import sys
import threading
import time

from process_scanner import get_process_path
from hash_utils import sha256_file
from virustotal import check_hash

from database import (
    initialize_database,
    insert_system_stats,
    get_recent_stats
)

# ─────────────────────────────────────────────
# Flask App
# ─────────────────────────────────────────────

app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────
# Database Init
# ─────────────────────────────────────────────

initialize_database()

# ─────────────────────────────────────────────
# Shutdown Handler
# ─────────────────────────────────────────────

def shutdown_handler(signum, frame):
    print("Backend shutting down...")
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)

# ─────────────────────────────────────────────
# Background Logging Thread
# ─────────────────────────────────────────────

def logging_loop():
    while True:
        cpu = psutil.cpu_percent()
        ram = psutil.virtual_memory().percent

        temp = 0

        insert_system_stats(cpu, ram, temp)

        time.sleep(5)

threading.Thread(
    target=logging_loop,
    daemon=True
).start()

# ─────────────────────────────────────────────
# Network Baseline
# ─────────────────────────────────────────────

_last_net = psutil.net_io_counters()
_last_time = time.time()

# ─────────────────────────────────────────────
# CPU Name Helper
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
# GPU Helper
# ─────────────────────────────────────────────

def _gpu_info() -> dict:
    try:
        import GPUtil

        gpus = GPUtil.getGPUs()

        if gpus:
            g = gpus[0]

            return {
                "gpu_name": g.name,
                "gpu_usage": int(g.load * 100),
                "gpu_temp": int(g.temperature),
            }

    except Exception:
        pass

    return {
        "gpu_name": "No GPU",
        "gpu_usage": 0,
        "gpu_temp": 0
    }

# ─────────────────────────────────────────────
# VirusTotal Process Check
# ─────────────────────────────────────────────

@app.route("/virustotal/process", methods=["POST"])
def virustotal_process():

    data = request.json

    if not data:
        return jsonify({
            "success": False,
            "error": "Missing JSON body"
        })

    pid = data.get("pid")

    if pid is None:
        return jsonify({
            "success": False,
            "error": "Missing PID"
        })

    path = get_process_path(pid)

    if not path:
        return jsonify({
            "success": False,
            "error": "Process path not found"
        })

    try:
        file_hash = sha256_file(path)

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        })

    result = check_hash(file_hash)

    return jsonify(result)

# ─────────────────────────────────────────────
# Stats Endpoint
# ─────────────────────────────────────────────

@app.route("/stats")
def stats():

    global _last_net, _last_time

    current_net = psutil.net_io_counters()
    current_time = time.time()

    elapsed = max(current_time - _last_time, 0.001)

    upload_speed = (
        (current_net.bytes_sent - _last_net.bytes_sent)
        / 1024
        / elapsed
    )

    download_speed = (
        (current_net.bytes_recv - _last_net.bytes_recv)
        / 1024
        / elapsed
    )

    _last_net = current_net
    _last_time = current_time

    core_percents = psutil.cpu_percent(
        interval=0.1,
        percpu=True
    )

    cpu_overall = (
        round(sum(core_percents) / len(core_percents))
        if core_percents else 0
    )

    vm = psutil.virtual_memory()

    ram_pct = int(vm.percent)
    ram_total = round(vm.total / (1024 ** 3))

    disk_pct = int(psutil.disk_usage("/").percent)

    data = {
        "cpu": cpu_overall,
        "cores": [int(x) for x in core_percents],

        "ram": ram_pct,
        "ram_total": ram_total,

        "disk": disk_pct,

        "upload": round(upload_speed, 1),
        "download": round(download_speed, 1),

        "cpu_name": _CPU_NAME,

        **_gpu_info()
    }

    return jsonify(data)

# ─────────────────────────────────────────────
# History Endpoint
# ─────────────────────────────────────────────

@app.route("/history")
def history():
    return jsonify(get_recent_stats())

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=False,
        threaded=True
    )