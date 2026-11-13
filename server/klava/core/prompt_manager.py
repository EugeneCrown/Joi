"""
Менеджер системных промптов.
Загружает Jinja2-шаблоны из config/prompts/ при старте и кэширует их.
Поддерживает hot-reload для разработки.
"""
import logging
from pathlib import Path
from typing import Any, Dict
from jinja2 import Environment, FileSystemLoader, Template

logger = logging.getLogger(__name__)


class PromptManager:
    """Менеджер промптов с кэшированием и hot-reload."""

    def __init__(self, prompts_dir: str | Path, hot_reload: bool = False):
        self.prompts_dir = Path(prompts_dir)
        self.hot_reload = hot_reload

        if not self.prompts_dir.exists():
            raise FileNotFoundError(f"Папка промптов не найдена: {self.prompts_dir}")

        self.env = Environment(
            loader=FileSystemLoader(str(self.prompts_dir)),
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=False,
            auto_reload=hot_reload,
        )

        self._templates: Dict[str, Template] = {}
        self._load_all_prompts()
        logger.info(f"✅ Загружено {len(self._templates)} шаблонов промптов из {self.prompts_dir}")

    def _load_all_prompts(self) -> None:
        """Рекурсивно загружает все .txt и .md файлы из папки prompts."""
        self._templates.clear()
        for file_path in self.prompts_dir.rglob("*"):
            if file_path.is_file() and file_path.suffix in [".txt", ".md"]:
                relative_path = file_path.relative_to(self.prompts_dir)
                template_name = str(relative_path.with_suffix(""))
                try:
                    self._templates[template_name] = self.env.get_template(str(relative_path))
                except Exception as e:
                    logger.error(f"Ошибка загрузки шаблона {template_name}: {e}")

    def render(self, template_name: str, **kwargs: Any) -> str:
        """
        Рендерит промпт с подстановкой переменных.

        Args:
            template_name: Имя шаблона без расширения (напр., "system/base")
            **kwargs: Переменные для подстановки

        Returns:
            Готовый текст промпта.
        """
        if self.hot_reload:
            # В режиме hot-reload перечитываем файл каждый раз (для разработки)
            try:
                template = self.env.get_template(f"{template_name}.txt")
                return template.render(**kwargs)
            except Exception:
                pass  # fallback на кэш

        if template_name not in self._templates:
            available = ", ".join(sorted(self._templates.keys()))
            raise ValueError(f"Шаблон '{template_name}' не найден. Доступные: {available}")

        try:
            return self._templates[template_name].render(**kwargs)
        except Exception as e:
            logger.error(f"Ошибка рендеринга промпта '{template_name}': {e}")
            return self._templates[template_name].render()

    def reload(self) -> None:
        """Перезагружает все шаблоны с диска."""
        self._load_all_prompts()
        logger.info("🔄 Шаблоны промптов перезагружены")

    def list_templates(self) -> list[str]:
        """Возвращает список всех загруженных шаблонов."""
        return sorted(self._templates.keys())


if __name__ == "__main__":
    from datetime import datetime

    logging.basicConfig(level=logging.INFO)
    manager = PromptManager(prompts_dir="../../config/prompts", hot_reload=True)

    print("Доступные шаблоны:")
    for t in manager.list_templates():
        print(f"  - {t}")

    print("\n--- Пример рендеринга system/base ---")
    result = manager.render(
        "system/base",
        current_time=datetime.now().strftime("%Y-%m-%d %H:%M"),
        user_name="Женя",
        retrieved_facts="- Использует Manjaro KDE\n- Предпочитает zram",
    )
    print(result)
