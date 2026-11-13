"""Менеджер промптов Joi: Jinja2 + кэш + автоподстановка идентичности."""
from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, Template

from joi.core.branding import IDENTITY, AgentIdentity

logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_PROMPTS_DIR = PROJECT_ROOT / "config" / "prompts"


class PromptManager:
    def __init__(
        self,
        prompts_dir: str | Path | None = None,
        hot_reload: bool = False,
        identity: AgentIdentity | None = None,
    ) -> None:
        self.prompts_dir = Path(prompts_dir) if prompts_dir else DEFAULT_PROMPTS_DIR
        if not self.prompts_dir.exists():
            raise FileNotFoundError(f"Папка промптов не найдена: {self.prompts_dir}")

        self.identity = identity or IDENTITY
        self.hot_reload = hot_reload
        self.env = Environment(
            loader=FileSystemLoader(str(self.prompts_dir)),
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=False,
            auto_reload=hot_reload,
        )
        self._templates: dict[str, Template] = {}
        self._load_all()
        logger.info("✅ [%s] загружено %d промптов", self.identity.name, len(self._templates))

    def _load_all(self) -> None:
        self._templates.clear()
        for path in sorted(self.prompts_dir.rglob("*")):
            if path.is_file() and path.suffix in {".txt", ".md"}:
                rel = path.relative_to(self.prompts_dir)
                key = str(rel.with_suffix(""))
                try:
                    self._templates[key] = self.env.get_template(str(rel))
                except Exception as exc:
                    logger.error("Ошибка загрузки промпта %s: %s", key, exc)

    def render(self, template_name: str, **kwargs: Any) -> str:
        context: dict[str, Any] = self.identity.prompt_vars()
        context.setdefault("current_time", datetime.now().strftime("%Y-%m-%d %H:%M"))
        context.update(kwargs)

        if self.hot_reload:
            for suffix in (".txt", ".md"):
                candidate = self.prompts_dir / f"{template_name}{suffix}"
                if candidate.exists():
                    return self.env.get_template(f"{template_name}{suffix}").render(**context)

        if template_name not in self._templates:
            available = ", ".join(sorted(self._templates))
            raise ValueError(f"Промпт '{template_name}' не найден. Доступные: {available}")

        try:
            return self._templates[template_name].render(**context)
        except Exception as exc:
            logger.error("Ошибка рендеринга '%s': %s", template_name, exc)
            return self._templates[template_name].render()

    def reload(self) -> None:
        self.env.cache.clear()
        self._load_all()

    def list_templates(self) -> list[str]:
        return sorted(self._templates)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    pm = PromptManager(hot_reload=True)
    print(f"Агент: {pm.identity.name} ({pm.identity.name_ru})")
    print("Промпты:", ", ".join(pm.list_templates()))
    print("\n--- system/base ---")
    print(pm.render("system/base", retrieved_facts="- Использует Manjaro KDE"))
