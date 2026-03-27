from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from ...models.schemas import SessionStatus, VARIResult
from ...storage.manager import storage

router = APIRouter()


@router.post("/sessions/{session_id}/process")
async def start_processing(session_id: str):
    from ...workers.tasks import run_pipeline

    session = storage.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")

    if session.photo_count == 0:
        raise HTTPException(status_code=400, detail="Nenhuma foto enviada para esta sessão")

    task = run_pipeline.delay(session_id)

    session.status = SessionStatus.processing
    session.server_job_id = task.id
    storage.update_session(session)

    return {"job_id": task.id}


@router.get("/sessions/{session_id}/results", response_model=VARIResult)
async def get_results(session_id: str):
    session = storage.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")
    if not session.vari_result:
        raise HTTPException(status_code=404, detail="Resultados ainda não disponíveis")
    return session.vari_result


@router.get("/sessions/{session_id}/export/ply")
async def export_ply(session_id: str):
    path = storage.get_ply_path(session_id)
    if not path:
        raise HTTPException(status_code=404, detail="Arquivo .ply não encontrado")
    return FileResponse(path, filename="point_cloud.ply", media_type="application/octet-stream")


@router.get("/sessions/{session_id}/export/report")
async def export_report(session_id: str):
    path = storage.get_report_path(session_id)
    if not path:
        raise HTTPException(status_code=404, detail="Relatório não encontrado")
    return FileResponse(path, filename="report.json", media_type="application/json")
