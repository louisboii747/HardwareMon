import sqlite3
import unittest

from database.history_query import (
    HISTORY_VALUE_COLUMNS,
    calculate_bucket_seconds,
    fetch_aggregated_history,
)


class HistoryBucketTests(unittest.TestCase):
    def test_short_ranges_keep_per_second_resolution(self):
        self.assertEqual(calculate_bucket_seconds(300, 720), 1)

    def test_long_ranges_are_bounded_to_requested_point_count(self):
        self.assertEqual(calculate_bucket_seconds(86_400, 720), 120)
        self.assertEqual(calculate_bucket_seconds(2_592_000, 720), 3600)

    def test_aggregation_query_downsamples_and_preserves_metrics(self):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        columns = ", ".join(f"{column} REAL" for column in HISTORY_VALUE_COLUMNS)
        conn.execute(
            f"""
            CREATE TABLE telemetry_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                {columns}
            )
            """
        )

        values = ", ".join("?" for _ in HISTORY_VALUE_COLUMNS)
        for seconds_ago, cpu_value in ((50, 10.0), (40, 30.0), (10, 80.0)):
            conn.execute(
                f"""
                INSERT INTO telemetry_history (
                    timestamp,
                    {", ".join(HISTORY_VALUE_COLUMNS)}
                )
                VALUES (
                    datetime('now', ?),
                    {values}
                )
                """,
                (
                    f"-{seconds_ago} seconds",
                    cpu_value,
                    *([1.0] * (len(HISTORY_VALUE_COLUMNS) - 1)),
                ),
            )

        rows = fetch_aggregated_history(conn, range_seconds=60, points=2)

        self.assertLessEqual(len(rows), 2)
        self.assertTrue(all(row["timestamp"] for row in rows))
        self.assertTrue(all(row["cpu_usage"] is not None for row in rows))
        conn.close()


if __name__ == "__main__":
    unittest.main()
