from __future__ import annotations

from pathlib import Path

from dynaconf import Dynaconf
from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class BackendConfig(BaseSettings):
    model: str
    model_provider: str
    model_base_url: str
    database_url: str
    context_window: int

    api_key: str = ""

    cors_allowed_origins: list[str] = ["http://localhost:5173"]
    CONTEXT_PANEL_MAX_CHARS: int = 2000
    ORCHESTRATOR_EVAL_EVERY_N: int = 1
    ORCHESTRATOR_THRESHOLD: float = 0.7
    ORCHESTRATOR_1TO1_THRESHOLD: float = 0.9
    ORCHESTRATOR_SUPPRESSION_WINDOW_MESSAGES: int = 20
    MAX_P2P_TURNS: int = 10
    P2P_TURN_DELAY_SECONDS: float = 1.0
    P2P_REPETITION_WINDOW: int = 5
    P2P_REPETITION_THRESHOLD: float = 0.85
    REVIEW_AGENT_SCHEDULE: str = "0 2 * * *"
    REVIEW_AGENT_CRASH_GRACE_SECONDS: int = 300
    MENTOR_PROMOTION_SCHEDULE: str = "0 3 * * *"
    MODEL_CALL_TIMEOUT_SECONDS: int = 60
    CONSULTATION_SESSION_TTL_SECONDS: int = 3600
    TEST_SESSION_TTL_SECONDS: int = 3600
    SSE_EVENT_BUFFER_SIZE: int = 100

    model_config = ConfigDict(extra="ignore")


def load_config(base_dir: Path | None = None) -> BackendConfig:
    root = base_dir or Path(__file__).parent.parent
    settings = Dynaconf(
        settings_files=[str(root / "config.json")],
        secrets=[str(root / "config.override.json")],
    )
    return BackendConfig(**settings.as_dict())
