from pathlib import Path
from typing import List, Optional

from loguru import logger

from ..config import settings
from ..models.schemas import FieldSession


class StorageManager:
    def __init__(self) -> None:
        self.sessions_path = settings.sessions_path

    # ── internal helpers ──────────────────────────────────────────────────────

    def _session_dir(self, session_id: str) -> Path:
        return self.sessions_path / session_id

    def _session_file(self, session_id: str) -> Path:
        return self._session_dir(session_id) / "session.json"

    def _photos_dir(self, session_id: str, photo_type: str) -> Path:
        path = self._session_dir(session_id) / "photos" / photo_type
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _results_dir(self, session_id: str) -> Path:
        path = self._session_dir(session_id) / "results"
        path.mkdir(parents=True, exist_ok=True)
        return path

    # ── session CRUD ──────────────────────────────────────────────────────────

    def create_session(self, session: FieldSession) -> FieldSession:
        self._session_dir(session.id).mkdir(parents=True, exist_ok=True)
        self._session_file(session.id).write_text(session.model_dump_json(indent=2))
        logger.info(f"Session created: {session.id}")
        return session

    def get_session(self, session_id: str) -> Optional[FieldSession]:
        file = self._session_file(session_id)
        if not file.exists():
            return None
        return FieldSession.model_validate_json(file.read_text())

    def update_session(self, session: FieldSession) -> FieldSession:
        self._session_file(session.id).write_text(session.model_dump_json(indent=2))
        return session

    def list_sessions(self) -> List[FieldSession]:
        if not self.sessions_path.exists():
            return []
        sessions = []
        for d in sorted(self.sessions_path.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            if d.is_dir():
                s = self.get_session(d.name)
                if s:
                    sessions.append(s)
        return sessions

    # ── photo storage ─────────────────────────────────────────────────────────

    def save_photo(self, session_id: str, photo_type: str, filename: str, data: bytes) -> Path:
        dest = self._photos_dir(session_id, photo_type) / filename
        dest.write_bytes(data)
        logger.debug(f"Photo saved: {dest}")
        return dest

    def get_photos_dir(self, session_id: str, photo_type: str) -> Path:
        return self._photos_dir(session_id, photo_type)

    # ── results ───────────────────────────────────────────────────────────────

    def get_results_dir(self, session_id: str) -> Path:
        return self._results_dir(session_id)

    def get_ply_path(self, session_id: str) -> Optional[Path]:
        p = self._results_dir(session_id) / "point_cloud.ply"
        return p if p.exists() else None

    def get_report_path(self, session_id: str) -> Optional[Path]:
        p = self._results_dir(session_id) / "report.json"
        return p if p.exists() else None

    def get_vari_map_path(self, session_id: str) -> Optional[Path]:
        p = self._results_dir(session_id) / "vari_map.png"
        return p if p.exists() else None

    # ── bootstrap ─────────────────────────────────────────────────────────────

    def ensure_dirs(self) -> None:
        self.sessions_path.mkdir(parents=True, exist_ok=True)


storage = StorageManager()
