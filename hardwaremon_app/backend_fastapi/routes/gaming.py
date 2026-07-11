from fastapi import APIRouter, HTTPException, Query, status

from gaming.service import GamingService


router = APIRouter(prefix="/gaming", tags=["gaming"])
gaming_service = GamingService()


@router.get("/current")
async def current_gaming_session():
    return gaming_service.get_current()


@router.get("/history")
async def gaming_history(limit: int = Query(default=50, ge=1, le=500)):
    return gaming_service.list_sessions(limit=limit)


@router.get("/latest")
async def latest_gaming_session():
    session = gaming_service.latest_session()
    if session is None:
        raise HTTPException(status_code=404, detail="No gaming sessions are available yet.")
    return session


@router.get("/session/{session_id}")
async def gaming_session(session_id: str):
    session = gaming_service.get_session(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Gaming session was not found.")
    return session


@router.delete("/session/{session_id}", status_code=status.HTTP_202_ACCEPTED)
async def delete_gaming_session(session_id: str):
    deleted = gaming_service.delete_session(session_id)
    if not deleted:
        active = gaming_service.get_current().get("session")
        if isinstance(active, dict) and active.get("id") == session_id:
            raise HTTPException(
                status_code=409,
                detail="An active gaming session cannot be deleted.",
            )
        raise HTTPException(status_code=404, detail="Gaming session was not found.")
    return {"status": "deleted", "id": session_id}


@router.get("/statistics")
async def gaming_statistics():
    return gaming_service.statistics()
