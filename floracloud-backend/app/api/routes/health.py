from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter()


@router.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "FloraCloud API",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/download/floracloud.apk")
async def download_apk():
    apk_path = Path("/data/floracloud/floracloud.apk")
    if not apk_path.exists():
        raise HTTPException(status_code=404, detail="APK não encontrado no servidor")
    return FileResponse(
        apk_path,
        filename="floracloud.apk",
        media_type="application/vnd.android.package-archive",
    )
