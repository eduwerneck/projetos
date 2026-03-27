from typing import List

from fastapi import APIRouter, HTTPException

from ...models.schemas import CreateSessionRequest, FieldSession
from ...storage.manager import storage

router = APIRouter()


@router.post("/sessions", response_model=dict, status_code=201)
async def create_session(request: CreateSessionRequest):
    session = FieldSession(
        name=request.name,
        description=request.description,
        location=request.location,
        gps_coordinate=request.gps_coordinate,
        gps_mode=request.gps_mode,
        plot_size_meters=request.plot_size_meters,
    )
    storage.create_session(session)
    return {"session_id": session.id}


@router.get("/sessions", response_model=List[FieldSession])
async def list_sessions():
    return storage.list_sessions()


@router.get("/sessions/{session_id}", response_model=FieldSession)
async def get_session(session_id: str):
    session = storage.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")
    return session
