from fastapi import FastAPI
from telemetry.system import router as system_router

app = FastAPI(
    title="HardwareMon Backend",
    version="1.0.0"
)

app.include_router(system_router)

@app.get("/")
async def root():
    return {
        "status": "online",
        "backend": "HardwareMon FastAPI"
    }