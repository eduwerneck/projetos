from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    app_name: str = "FloraCloud API"
    debug: bool = False
    storage_path: str = "/data/floracloud"
    redis_url: str = "redis://redis:6379/0"
    panel_reflectance: float = 0.18  # default: 18% gray reflectance panel
    depth_model_name: str = "depth-anything/Depth-Anything-V2-Small-hf"

    model_config = {"env_file": ".env"}

    @property
    def sessions_path(self) -> Path:
        return Path(self.storage_path) / "sessions"


settings = Settings()
