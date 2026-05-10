import json
import psutil

data = {
    "cpu": int(psutil.cpu_percent(interval=1)),
    "ram": int(psutil.virtual_memory().percent),
    "disk": int(psutil.disk_usage('/').percent)
}

print(json.dumps(data), flush=True)