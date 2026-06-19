from fastapi import APIRouter
from database.database import get_connection

router = APIRouter()


@router.get("/history")
async def get_history(limit: int = 100):
    conn = get_connection()

    rows = conn.execute(
        """
        SELECT *
        FROM telemetry_history
        ORDER BY id DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()

    conn.close()

    return [dict(row) for row in rows]
