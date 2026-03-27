from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger

from .api.routes import health, jobs, photos, results, sessions
from .config import settings
from .storage.manager import storage


@asynccontextmanager
async def lifespan(app: FastAPI):
    storage.ensure_dirs()
    logger.info(f"FloraCloud API started. Storage: {settings.storage_path}")
    yield
    logger.info("FloraCloud API stopped.")


app = FastAPI(
    title="FloraCloud API",
    description="API para mapeamento 3D de vegetação com SfM e VARI",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(sessions.router, prefix="/api")
app.include_router(photos.router, prefix="/api")
app.include_router(jobs.router, prefix="/api")
app.include_router(results.router, prefix="/api")
