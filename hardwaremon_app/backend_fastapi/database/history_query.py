import math


HISTORY_VALUE_COLUMNS = (
    "cpu_usage",
    "cpu_temp",
    "cpu_power",
    "cpu_clock",
    "ram_usage",
    "ram_used",
    "ram_available",
    "gpu_usage",
    "gpu_temp",
    "gpu_power",
    "gpu_vram_used",
)


def calculate_bucket_seconds(range_seconds: int, points: int) -> int:
    return max(1, math.ceil(range_seconds / points))


def fetch_aggregated_history(conn, range_seconds: int, points: int):
    bucket_seconds = calculate_bucket_seconds(range_seconds, points)
    averages = ",\n".join(
        f"AVG({column}) AS {column}" for column in HISTORY_VALUE_COLUMNS
    )

    return conn.execute(
        f"""
        SELECT
            MIN(id) AS id,
            datetime(
                (CAST(strftime('%s', timestamp) AS INTEGER) / ?) * ?,
                'unixepoch'
            ) AS timestamp,
            {averages}
        FROM telemetry_history
        WHERE timestamp >= datetime('now', ?)
        GROUP BY CAST(strftime('%s', timestamp) AS INTEGER) / ?
        ORDER BY timestamp DESC
        LIMIT ?
        """,
        (
            bucket_seconds,
            bucket_seconds,
            f"-{range_seconds} seconds",
            bucket_seconds,
            points,
        ),
    ).fetchall()
