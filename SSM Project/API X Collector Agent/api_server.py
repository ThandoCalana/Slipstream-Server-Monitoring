from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from contextlib import asynccontextmanager
from databases import Database
from models import system_metrics
from datetime import datetime
import os

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Vongola10@localhost:5432/SSM")

database = Database(DATABASE_URL)

@asynccontextmanager
async def lifespan(app:FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)

class Metrics(BaseModel):
    mem_free_GB: float
    mem_used_GB: float
    mem_total_GB: float
    cpu_percentage: float
    disk_used_GB: float
    disk_total_GB: float
    disk_free_GB: float
    rec_time: datetime

@app.post("/track")
async def track_metrics(metrics: Metrics):
    try:
        query = system_metrics.insert().values(**metrics.model_dump())
        await database.execute(query)
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")