import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "hardwaremon.db"


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

    conn.commit()
    conn.close()

    print(f"SQLite database initialized: {DB_PATH}")


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