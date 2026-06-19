import os
import platform
import sqlite3
from pathlib import Path


def get_data_dir():
    if platform.system() == "Windows":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        if base:
            data_dir = Path(base) / "HardwareMon"
        else:
            data_dir = Path.home() / "AppData" / "Local" / "HardwareMon"
    else:
        data_dir = Path.home() / ".local" / "share" / "hardwaremon"

    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir


def get_connection():
    conn = sqlite3.connect(get_data_dir() / "hardwaremon.db")
    conn.row_factory = sqlite3.Row
    return conn


def init_database():
    conn = get_connection()

    conn.execute("""
        CREATE TABLE IF NOT EXISTS telemetry_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            cpu_usage REAL,
            cpu_temp REAL,
            cpu_power REAL,
            cpu_clock REAL,
            ram_usage REAL,
            ram_used REAL,
            ram_available REAL,
            gpu_usage REAL,
            gpu_temp REAL,
            gpu_power REAL,
            gpu_vram_used REAL
        )
    """)

    conn.commit()
    conn.close()
