from fastapi import APIRouter, HTTPException
import psutil

router = APIRouter()


@router.get("/processes")
def get_processes():
    processes = []

    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
        try:
            info = proc.info
            if info["name"] in ["System Idle Process", "System"]:
                continue

            ram_mb = info["memory_info"].rss / 1024 / 1024 if info["memory_info"] else 0

            processes.append(
                {
                    "pid": info["pid"],
                    "name": info["name"],
                    "cpu": round(info["cpu_percent"] / psutil.cpu_count(), 1),
                    "ram": round(ram_mb, 1),
                }
            )

        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    processes.sort(key=lambda x: x["cpu"], reverse=True)

    return processes


@router.post("/kill/{pid}")
def kill_process(pid: int):
    try:
        process = psutil.Process(pid)

        process.terminate()

        try:
            process.wait(timeout=3)
        except psutil.TimeoutExpired:
            process.kill()

        return {"success": True, "pid": pid}

    except psutil.NoSuchProcess:
        raise HTTPException(status_code=404, detail="Process not found")

    except psutil.AccessDenied:
        raise HTTPException(status_code=403, detail="Access denied")
