from celery import Celery
from loguru import logger

from ..config import settings

celery_app = Celery(
    "floracloud",
    broker=settings.redis_url,
    backend=settings.redis_url,
)
celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
)


@celery_app.task(bind=True, name="floracloud.run_pipeline")
def run_pipeline(self, session_id: str):
    """FloraCloud pipeline: calibration → VARI → export."""
    from datetime import datetime, timezone

    from ..models.schemas import SessionStatus, VARIResult
    from ..pipeline.calibration import calibrate_photos
    from ..pipeline.vari import compute_vari_from_images, generate_vari_map
    from ..storage.manager import storage

    def stage(name: str, progress: float, message: str):
        self.update_state(
            state="STARTED",
            meta={"stage": name, "progress": progress, "message": message},
        )
        logger.info(f"[{session_id}] [{name}] {message}")

    try:
        session = storage.get_session(session_id)
        if not session:
            raise ValueError(f"Sessão não encontrada: {session_id}")

        results_dir = storage.get_results_dir(session_id)

        # ── 1. Radiometric calibration ────────────────────────────────────────
        stage("calibration", 0.10, "Calibração radiométrica com painel ArUco...")
        cal_entry = storage.get_photos_dir(session_id, "calibration_entry")
        cal_exit = storage.get_photos_dir(session_id, "calibration_exit")
        field_dir = storage.get_photos_dir(session_id, "field")
        calibrated_dir = results_dir / "calibrated"
        calibrated_dir.mkdir(exist_ok=True)

        correction_factors = calibrate_photos(cal_entry, cal_exit, calibrated_dir, field_dir)

        # ── 2. VARI from calibrated images ────────────────────────────────────
        stage("vari", 0.50, "Calculando índice VARI nas imagens calibradas...")
        vari_data = compute_vari_from_images(calibrated_dir, correction_factors)

        # ── 3. VARI colormap image ────────────────────────────────────────────
        stage("vari_map", 0.70, "Gerando mapa colorido VARI...")
        try:
            vari_map_path = generate_vari_map(calibrated_dir, correction_factors, results_dir)
            vari_data["vari_map_path"] = str(vari_map_path)
        except Exception as e:
            logger.warning(f"Falha ao gerar mapa VARI: {e}")
            vari_data["vari_map_path"] = None

        # ── 4. Save report JSON ───────────────────────────────────────────────
        stage("export", 0.90, "Salvando relatório JSON...")
        import json
        report = {
            "session_id": session_id,
            "processed_at": datetime.now(timezone.utc).isoformat(),
            "vari": {k: v for k, v in vari_data.items()},
        }
        report_path = results_dir / "report.json"
        report_path.write_text(json.dumps(report, indent=2))

        # ── Save results to session ───────────────────────────────────────────
        vari_result = VARIResult(
            mean=vari_data["mean"],
            median=vari_data["median"],
            std_dev=vari_data["std_dev"],
            min=vari_data["min"],
            max=vari_data["max"],
            point_count=vari_data["point_count"],
            stratified_by_height=vari_data["stratified_by_height"],
            ply_file_path=None,
            report_json_path=str(report_path),
            processed_at=datetime.now(timezone.utc).isoformat(),
        )
        session.vari_result = vari_result
        session.status = SessionStatus.completed
        storage.update_session(session)

        stage("done", 1.0, "Pipeline concluído com sucesso!")
        return {"status": "completed", "session_id": session_id}

    except Exception as exc:
        logger.exception(f"Pipeline falhou para sessão {session_id}: {exc}")
        try:
            session = storage.get_session(session_id)
            if session:
                session.status = SessionStatus.error
                session.error_message = str(exc)
                storage.update_session(session)
        except Exception:
            pass
        raise
