from flask import Flask, jsonify
from flask_cors import CORS

import psutil
import GPUtil
import platform
import time

app = Flask(__name__)
CORS(app)

last_net = psutil.net_io_counters()
last_time = time.time()


@app.route("/stats")
def stats():
    global last_net
    global last_time

    current_net = psutil.net_io_counters()
    current_time = time.time()

    elapsed = current_time - last_time

    upload_speed = (
        current_net.bytes_sent - last_net.bytes_sent
    ) / 1024 / elapsed

    download_speed = (
        current_net.bytes_recv - last_net.bytes_recv
    ) / 1024 / elapsed

    last_net = current_net
    last_time = current_time

    gpus = GPUtil.getGPUs()

    if gpus:
        gpu = gpus[0]

        gpu_usage = int(gpu.load * 100)
        gpu_temp = int(gpu.temperature)
        gpu_name = gpu.name

    else:
        gpu_usage = 0
        gpu_temp = 0
        gpu_name = "No GPU"

    try:
        cpu_name = (
            open("/proc/cpuinfo")
            .read()
            .split("model name")[1]
            .split(":")[1]
            .split("\n")[0]
            .strip()
        )
    except:
        cpu_name = platform.processor()

    ram_total = round(
        psutil.virtual_memory().total / (1024 ** 3)
    )

    data = {
        "cpu": int(psutil.cpu_percent()),
        "cores": [
            int(x)
            for x in psutil.cpu_percent(
                percpu=True
            )
        ],
        "ram": int(psutil.virtual_memory().percent),
        "disk": int(psutil.disk_usage('/').percent),

        "upload": round(upload_speed, 1),
        "download": round(download_speed, 1),

        "gpu_usage": gpu_usage,
        "gpu_temp": gpu_temp,

        "cpu_name": cpu_name,
        "gpu_name": gpu_name,
        "ram_total": ram_total,
    }

    return jsonify(data)


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=False
    )