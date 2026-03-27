from fastapi import APIRouter

from ...models.schemas import JobStatus
from ...workers.tasks import celery_app

router = APIRouter()


@router.get("/jobs/{job_id}", response_model=JobStatus)
async def get_job_status(job_id: str):
    from celery.result import AsyncResult

    result = AsyncResult(job_id, app=celery_app)

    if result.state == "PENDING":
        return JobStatus(job_id=job_id, status="pending", message="Aguardando na fila...")

    if result.state == "STARTED":
        info = result.info or {}
        return JobStatus(
            job_id=job_id,
            status="running",
            stage=info.get("stage"),
            progress=info.get("progress", 0.0),
            message=info.get("message"),
        )

    if result.state == "SUCCESS":
        return JobStatus(job_id=job_id, status="completed", progress=1.0, message="Concluído!")

    if result.state == "FAILURE":
        return JobStatus(job_id=job_id, status="failed", error=str(result.result))

    # Custom states emitted via update_state
    info = result.info if isinstance(result.info, dict) else {}
    return JobStatus(
        job_id=job_id,
        status=result.state.lower(),
        stage=info.get("stage"),
        progress=info.get("progress", 0.0),
        message=info.get("message"),
    )
