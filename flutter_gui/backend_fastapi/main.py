from fastapi import FastAPI
from telemetry.system import router as system_router
from routes.processes import router as processes_router

from lhm_launcher import start_lhm

app = FastAPI(
    title="HardwareMon Backend",
    version="1.0.0"
)

app.include_router(system_router)
app.include_router(processes_router)


@app.get("/")
async def root():
    return {
        "status": "online",
        "backend": "HardwareMon FastAPI"
    }


import uvicorn

if __name__ == "__main__":

    # Start LibreHardwareMonitor on Windows
    start_lhm()

    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8000
    )