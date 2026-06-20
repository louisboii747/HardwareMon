from typing import Optional

from fastapi import APIRouter, Query

from database.database import get_connection
from database.history_query import fetch_aggregated_history

router = APIRouter()

@router.get("/history")
async def get_history(
    limit: int = Query(default=100, ge=1, le=5000),
    range_seconds: Optional[int] = Query(default=None, ge=60, le=2_592_000),
    points: int = Query(default=720, ge=30, le=2000),
):
    conn = get_connection()

    try:
        if range_seconds is None:
            rows = conn.execute(
                """
                SELECT *
                FROM telemetry_history
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        else:
            rows = fetch_aggregated_history(conn, range_seconds, points)

        return [dict(row) for row in rows]
    finally:
        conn.close()
