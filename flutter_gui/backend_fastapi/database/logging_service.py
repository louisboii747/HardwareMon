import threading
import time

from database.database import get_connection
from telemetry.system import collect_stats


def log_telemetry():
    while True:
        try:
            stats = collect_stats()

            conn = get_connection()

            conn.execute(
                """
                INSERT INTO telemetry_history (
                    cpu_usage,
                    cpu_temp,
                    cpu_power,
                    cpu_clock,
                    ram_usage,
                    ram_used,
                    ram_available,
                    gpu_usage,
                    gpu_temp,
                    gpu_power,
                    gpu_vram_used
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    stats["cpu"],
                    stats["cpu_temp"],
                    stats["cpu_power"],
                    stats["cpu_clock"],
                    stats["ram"],
                    stats["ram_used"],
                    stats["ram_available"],
                    stats["gpu_usage"],
                    stats["gpu_temp"],
                    stats["gpu_power"],
                    stats["gpu_vram_used"],
                ),
            )

            conn.commit()
            conn.close()

            print("Logged telemetry sample")

        except Exception as e:
            print(f"Logging error: {e}")

        time.sleep(5)


def start_logging():
    thread = threading.Thread(
        target=log_telemetry,
        daemon=True,
    )

    thread.start()
