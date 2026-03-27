from datetime import datetime, timezone

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "FloraCloud API",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
