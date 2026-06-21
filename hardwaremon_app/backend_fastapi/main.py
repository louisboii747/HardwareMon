from contextlib import asynccontextmanager
import os
import threading

from fastapi import FastAPI
from telemetry.system import router as system_router
from telemetry.network import router as network_router
from telemetry.storage import router as storage_router
from routes.processes import router as processes_router
from multiprocessing import freeze_support
from database.database import init_database
from lhm_launcher import start_lhm
from database.logging_service import start_logging
from routes.history import router as history_router
from routes.optimization import router as optimization_router


BACKEND_VERSION = "1.1.0"


freeze_support()  # Ensure compatibility with Windows


@asynccontextmanager
async def lifespan(_app):
    init_database()

    # LHM can require elevation and may take several seconds to expose its web
    # server. It must not delay FastAPI from accepting the GUI's health checks.
    threading.Thread(target=start_lhm, daemon=True, name="lhm-launcher").start()
    start_logging()

    yield


app = FastAPI(
    title="HardwareMon Backend",
    version=BACKEND_VERSION,
    lifespan=lifespan,
)

app.include_router(system_router)
app.include_router(network_router)
app.include_router(storage_router)
app.include_router(processes_router)
app.include_router(history_router)
app.include_router(optimization_router)


@app.get("/")
async def root():
    return {
        "status": "online",
        "backend": "HardwareMon FastAPI",
        "version": BACKEND_VERSION,
    }


import uvicorn

if __name__ == "__main__":
    port = int(os.environ.get("HARDWAREMON_BACKEND_PORT", "8000"))
    uvicorn.run(app, host="127.0.0.1", port=port, access_log=False)
