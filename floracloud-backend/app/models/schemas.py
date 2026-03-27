from __future__ import annotations

import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, Optional

from pydantic import BaseModel, Field


class SessionStatus(str, Enum):
    created = "created"
    capturing = "capturing"
    captured = "captured"
    uploading = "uploading"
    processing = "processing"
    completed = "completed"
    error = "error"


class GpsMode(str, Enum):
    cellphone = "cellphone"
    geodetic = "geodetic"


class GpsCoordinate(BaseModel):
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    accuracy: Optional[float] = None


class VARIResult(BaseModel):
    mean: float
    median: float
    std_dev: float
    min: float
    max: float
    point_count: int
    stratified_by_height: Dict[str, float]
    ply_file_path: Optional[str] = None
    report_json_path: Optional[str] = None
    processed_at: str


class FieldSession(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: Optional[str] = None
    location: Optional[str] = None
    gps_coordinate: Optional[GpsCoordinate] = None
    gps_mode: GpsMode = GpsMode.cellphone
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    status: SessionStatus = SessionStatus.created
    photo_count: int = 0
    calibration_photos: int = 0
    server_job_id: Optional[str] = None
    error_message: Optional[str] = None
    vari_result: Optional[VARIResult] = None
    plot_size_meters: float = 30.0


class CreateSessionRequest(BaseModel):
    name: str
    description: Optional[str] = None
    location: Optional[str] = None
    gps_coordinate: Optional[GpsCoordinate] = None
    gps_mode: GpsMode = GpsMode.cellphone
    plot_size_meters: float = 30.0


class JobStatus(BaseModel):
    job_id: str
    status: str  # pending | running | completed | failed
    stage: Optional[str] = None
    progress: float = 0.0
    message: Optional[str] = None
    error: Optional[str] = None
