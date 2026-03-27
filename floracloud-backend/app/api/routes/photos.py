from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from ...models.schemas import SessionStatus
from ...storage.manager import storage

router = APIRouter()

VALID_TYPES = {"calibration_entry", "calibration_midpoint", "calibration_exit", "field"}


@router.post("/sessions/{session_id}/photos")
async def upload_photo(
    session_id: str,
    photo: UploadFile = File(...),
    type: str = Form(...),
):
    if type not in VALID_TYPES:
        raise HTTPException(status_code=400, detail=f"Tipo inválido: {type}. Use: {VALID_TYPES}")

    session = storage.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")

    data = await photo.read()
    filename = photo.filename or f"{type}_{session.photo_count + 1}.jpg"
    storage.save_photo(session_id, type, filename, data)

    session.photo_count += 1
    if type != "field":
        session.calibration_photos += 1
    session.status = SessionStatus.uploading
    storage.update_session(session)

    return {"status": "ok", "filename": filename}
