from fastapi import FastAPI
from telemetry.system import router as system_router
from routes.processes import router as processes_router
from multiprocessing import freeze_support
from database.database import init_database
from lhm_launcher import start_lhm
from database.logging_service import start_logging
from routes.history import router as history_router


freeze_support()  # Ensure compatibility with Windows

start_lhm()  # Start the LHM process
init_database()  # Initialize the database
start_logging()  # Start the logging process

app = FastAPI(title="HardwareMon Backend", version="1.0.0")

app.include_router(system_router)
app.include_router(processes_router)
app.include_router(history_router)


@app.get("/")
async def root():
    return {"status": "online", "backend": "HardwareMon FastAPI"}


import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
