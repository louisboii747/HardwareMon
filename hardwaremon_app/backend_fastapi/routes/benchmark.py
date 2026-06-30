from fastapi import APIRouter, HTTPException, Query, status

from benchmark.service import (
    BenchmarkAlreadyRunningError,
    BenchmarkNotRunningError,
    BenchmarkService,
)


router = APIRouter(prefix="/benchmark", tags=["benchmark"])
benchmark_service = BenchmarkService()


@router.post("/start", status_code=status.HTTP_202_ACCEPTED)
async def start_benchmark():
    try:
        return benchmark_service.start()
    except BenchmarkAlreadyRunningError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get("/status")
async def benchmark_status():
    return benchmark_service.get_status()


@router.get("/latest")
async def latest_benchmark_result():
    result = benchmark_service.latest_result()
    if result is None:
        raise HTTPException(status_code=404, detail="No benchmark results are available yet.")
    return result


@router.get("/results")
async def benchmark_results(limit: int = Query(default=20, ge=1, le=100)):
    return benchmark_service.list_results(limit=limit)


@router.post("/cancel", status_code=status.HTTP_202_ACCEPTED)
async def cancel_benchmark():
    try:
        return benchmark_service.cancel()
    except BenchmarkNotRunningError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
