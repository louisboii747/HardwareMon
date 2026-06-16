import sqlite3


def get_connection():
    return sqlite3.connect("hardwaremon.db")


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
