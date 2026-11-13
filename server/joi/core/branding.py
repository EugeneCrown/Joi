"""Единый источник имени и идентичности ассистента Joi."""
from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONFIG = PROJECT_ROOT / "config" / "agent.yaml"


@dataclass(frozen=True)
class AgentIdentity:
    name: str = "Joi"
    name_ru: str = "Джой"
    tts_name: str = "Джой"
    language: str = "ru"
    version: str = "0.1.0"
    wake_words: tuple[str, ...] = ("джой", "джои", "joi")
    user_name: str = "Женя"
    user_name_stress: str = "ЖЕ-ня"
    user_os: str = "Manjaro Linux (KDE Plasma, X11)"
    style: str = "кратко, по делу, дружелюбно, без воды"

    def prompt_vars(self) -> dict[str, Any]:
        return {
            "agent_name": self.name,
            "agent_name_ru": self.name_ru,
            "agent_tts_name": self.tts_name,
            "user_name": self.user_name,
            "user_name_stress": self.user_name_stress,
            "user_os": self.user_os,
        }


def load_identity(config_path: str | Path | None = None) -> AgentIdentity:
    path = Path(config_path) if config_path else DEFAULT_CONFIG
    try:
        import yaml
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        agent = raw.get("agent", {})
        user = raw.get("user", {})
        return AgentIdentity(
            name=agent.get("name", "Joi"),
            name_ru=agent.get("name_ru", "Джой"),
            tts_name=agent.get("tts_name", "Джой"),
            language=agent.get("language", "ru"),
            version=str(agent.get("version", "0.1.0")),
            wake_words=tuple(agent.get("wake_words", ("джой", "джои", "joi"))),
            user_name=user.get("name", "Женя"),
            user_name_stress=user.get("name_stress", "ЖЕ-ня"),
            user_os=user.get("os", "Manjaro Linux (KDE Plasma, X11)"),
            style=agent.get("personality", {}).get("style", AgentIdentity.style),
        )
    except Exception as exc:
        logger.warning("Не удалось прочитать %s (%s) — дефолт Joi", path, exc)
        return AgentIdentity()


IDENTITY = load_identity()
