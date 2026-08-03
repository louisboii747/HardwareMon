import os
import sys
import threading
import logging
from contextlib import asynccontextmanager
from multiprocessing import freeze_support

from app_paths import ensure_app_paths, startup_diagnostics
from database.database import init_database
from database.logging_service import start_logging
from fastapi import FastAPI
from lhm_launcher import start_lhm
from routes.benchmark import router as benchmark_router
from routes.gaming import gaming_service
from routes.gaming import router as gaming_router
from routes.history import router as history_router
from routes.inventory import router as inventory_router
from routes.optimization import router as optimization_router
from plugins.broker import PluginBroker
from routes.plugins import router as plugins_router
from routes.processes import router as processes_router
from telemetry.network import router as network_router
from telemetry.storage import router as storage_router
from telemetry.system import router as system_router

BACKEND_VERSION = "1.2.0"


freeze_support()  # Ensure compatibility with Windows


@asynccontextmanager
async def lifespan(_app):
    paths = ensure_app_paths()
    diagnostics = startup_diagnostics(paths)
    logging.getLogger("hardwaremon.startup").info("startup_paths %s", diagnostics)
    _app.state.startup_diagnostics = diagnostics
    _app.state.database_ready = False
    _app.state.plugin_status = {"state": "initializing", "error": None}
    init_database()
    _app.state.database_ready = True

    # LHM can require elevation and may take several seconds to expose its web
    # server. It must not delay FastAPI from accepting the GUI's health checks.
    threading.Thread(target=start_lhm, daemon=True, name="lhm-launcher").start()
    start_logging()
    gaming_service.start()
    plugin_broker = None
    try:
        plugin_broker = PluginBroker(data_dir=paths.data_dir)
        plugin_broker.start()
        _app.state.plugin_broker = plugin_broker
        _app.state.plugin_status = {"state": "ready", "error": None}
    except Exception as exc:
        logging.getLogger("hardwaremon.startup").exception("Plugin subsystem degraded")
        _app.state.plugin_status = {"state": "degraded", "error": str(exc)}

    try:
        yield
    finally:
        gaming_service.stop()
        if plugin_broker is not None:
            plugin_broker.stop()


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
app.include_router(benchmark_router)
app.include_router(gaming_router)
app.include_router(inventory_router)
app.include_router(plugins_router)


@app.get("/")
async def root():
    return {
        "status": "online",
        "backend": "HardwareMon FastAPI",
        "version": BACKEND_VERSION,
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "core": "ready",
        "database": "ready" if app.state.database_ready else "not_ready",
        "plugins": app.state.plugin_status,
        "startup": app.state.startup_diagnostics,
    }


import uvicorn

if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--plugin-runner":
        import runpy

        runpy.run_path(sys.argv[2], run_name="__main__")
    else:
        port = int(os.environ.get("HARDWAREMON_BACKEND_PORT", "8000"))
        uvicorn.run(app, host="127.0.0.1", port=port, access_log=False)
