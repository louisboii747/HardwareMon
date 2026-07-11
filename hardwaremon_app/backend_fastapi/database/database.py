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


def init_benchmark_schema(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS benchmark_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            device_name TEXT NOT NULL,
            platform TEXT NOT NULL,
            cpu_model TEXT NOT NULL,
            cpu_cores INTEGER NOT NULL DEFAULT 0,
            cpu_threads INTEGER NOT NULL DEFAULT 0,
            gpu_model TEXT,
            ram_total INTEGER NOT NULL,
            ram_speed_mhz INTEGER,
            storage_type TEXT,
            operating_system TEXT NOT NULL DEFAULT 'Unknown',
            benchmark_version TEXT NOT NULL,
            overall_score INTEGER NOT NULL,
            cpu_score INTEGER NOT NULL,
            memory_score INTEGER NOT NULL,
            disk_score INTEGER NOT NULL,
            duration REAL NOT NULL,
            raw_result_json TEXT NOT NULL
        )
    """)

    # Additive migration for benchmark databases created by score format v1.
    # SQLite cannot add several columns in one ALTER statement, so each missing
    # hardware field is introduced independently without rewriting old results.
    columns = {
        row["name"] if hasattr(row, "keys") else row[1]
        for row in conn.execute("PRAGMA table_info(benchmark_results)")
    }
    migrations = {
        "cpu_cores": "INTEGER NOT NULL DEFAULT 0",
        "cpu_threads": "INTEGER NOT NULL DEFAULT 0",
        "gpu_model": "TEXT",
        "ram_speed_mhz": "INTEGER",
        "storage_type": "TEXT",
        "operating_system": "TEXT NOT NULL DEFAULT 'Unknown'",
    }
    for name, definition in migrations.items():
        if name not in columns:
            conn.execute(
                f"ALTER TABLE benchmark_results ADD COLUMN {name} {definition}"
            )
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_benchmark_results_timestamp
        ON benchmark_results (timestamp DESC)
    """)


def init_gaming_schema(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS gaming_sessions (
            id TEXT PRIMARY KEY,
            game_name TEXT NOT NULL,
            executable TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            duration_seconds REAL NOT NULL DEFAULT 0,
            platform TEXT NOT NULL,
            avg_cpu_usage REAL,
            avg_gpu_usage REAL,
            avg_ram_usage REAL,
            avg_cpu_temperature REAL,
            avg_gpu_temperature REAL,
            peak_cpu_temperature REAL,
            peak_gpu_temperature REAL,
            peak_ram_usage REAL,
            peak_gpu_usage REAL,
            avg_cpu_clock REAL,
            avg_gpu_power REAL,
            avg_cpu_power REAL,
            max_cpu_usage REAL,
            max_gpu_usage REAL,
            total_samples INTEGER NOT NULL DEFAULT 0,
            hardwaremon_version TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            raw_session_json TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    columns = {
        row["name"] if hasattr(row, "keys") else row[1]
        for row in conn.execute("PRAGMA table_info(gaming_sessions)")
    }
    migrations = {
        "status": "TEXT NOT NULL DEFAULT 'active'",
        "raw_session_json": "TEXT NOT NULL DEFAULT '{}'",
        "created_at": "TEXT",
        "updated_at": "TEXT",
    }
    for name, definition in migrations.items():
        if name not in columns:
            conn.execute(f"ALTER TABLE gaming_sessions ADD COLUMN {name} {definition}")

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_gaming_sessions_started_at
        ON gaming_sessions (started_at DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_gaming_sessions_game_name
        ON gaming_sessions (game_name)
    """)


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

    conn.execute("""
        CREATE TABLE IF NOT EXISTS storage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            drive_id TEXT NOT NULL,
            mount_point TEXT NOT NULL,
            capacity_percent REAL,
            read_bps REAL,
            write_bps REAL,
            temperature_c REAL
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_storage_history_drive_timestamp
        ON storage_history (drive_id, timestamp)
    """)

    init_benchmark_schema(conn)
    init_gaming_schema(conn)

    conn.commit()
    conn.close()
