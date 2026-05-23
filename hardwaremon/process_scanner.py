import psutil

def get_process_path(pid):
    try:
        proc = psutil.Process(pid)
        return proc.exe()

    except Exception as e:
        print(f"Process lookup failed: {e}")
        return None