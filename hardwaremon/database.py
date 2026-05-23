import sqlite3
from pathlib import Path

DATA_DIR = Path.home() / ".var/app/com.hardwaremon.HardwareMon/data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = DATA_DIR / "hardwaremon.db"

def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def initialize_database():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS system_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            cpu_percent REAL,
            ram_percent REAL,
            cpu_temp REAL
        )
    """)

    initialize_settings_table(conn)
    if get_setting("refresh_interval") is None:
        set_setting("refresh_interval", "2")

    conn.commit()
    conn.close()

    print(f"SQLite database initialized: {DB_PATH}")


def initialize_settings_table(conn):
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)

    conn.commit()

def set_setting(key, value):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT OR REPLACE INTO settings (key, value)
        VALUES (?, ?)
    """, (key, value))

    conn.commit()
    conn.close()


def get_setting(key):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT value FROM settings
        WHERE key = ?
    """, (key,))

    row = cursor.fetchone()

    conn.close()

    return row["value"] if row else None


def insert_system_stats(cpu_percent, ram_percent, cpu_temp):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO system_stats (
            cpu_percent,
            ram_percent,
            cpu_temp
        )
        VALUES (?, ?, ?)
    """, (cpu_percent, ram_percent, cpu_temp))

    conn.commit()
    conn.close()


def get_recent_stats(limit=100):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT *
        FROM system_stats
        ORDER BY timestamp DESC
        LIMIT ?
    """, (limit,))

    rows = cursor.fetchall()

    conn.close()

    return [dict(row) for row in rows]

