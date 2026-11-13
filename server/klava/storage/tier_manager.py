"""
Менеджер многоуровневого хранилища (Hot / Warm / Cold).
Управляет миграцией данных между уровнями по возрасту и размеру.
"""
import logging
import shutil
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


@dataclass
class TierConfig:
    """Конфигурация одного уровня хранения."""
    name: str
    path: Path
    max_size_gb: int
    retention_days: int  # -1 = хранить вечно

    @property
    def max_size_bytes(self) -> int:
        return self.max_size_gb * (1024 ** 3)


class TierManager:
    """Управляет данными между Hot/Warm/Cold tiers."""

    def __init__(self, tiers: list[TierConfig]):
        if len(tiers) != 3:
            raise ValueError("Ожидается ровно 3 tier'а: hot, warm, cold")
        self.hot, self.warm, self.cold = tiers
        self._ensure_dirs()

    def _ensure_dirs(self) -> None:
        """Создает директории tiers, если их нет."""
        for tier in [self.hot, self.warm, self.cold]:
            tier.path.mkdir(parents=True, exist_ok=True)
            logger.info(f"📁 Tier '{tier.name}': {tier.path}")

    def get_tier_for_file(self, file_path: Path) -> Optional[TierConfig]:
        """Определяет, к какому tier'у принадлежит файл."""
        for tier in [self.hot, self.warm, self.cold]:
            try:
                file_path.relative_to(tier.path)
                return tier
            except ValueError:
                continue
        return None

    def migrate_by_age(self, days_threshold: int, from_tier: TierConfig, to_tier: TierConfig) -> int:
        """
        Перемещает файлы старше days_threshold из from_tier в to_tier.
        Возвращает количество перемещенных файлов.
        """
        cutoff = datetime.now() - timedelta(days=days_threshold)
        moved = 0

        for file_path in from_tier.path.rglob("*"):
            if not file_path.is_file():
                continue
            mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
            if mtime < cutoff:
                # Сохраняем относительную структуру
                rel_path = file_path.relative_to(from_tier.path)
                dest = to_tier.path / rel_path
                dest.parent.mkdir(parents=True, exist_ok=True)

                shutil.move(str(file_path), str(dest))
                moved += 1
                logger.debug(f"📦 {file_path.name} → {to_tier.name}")

        logger.info(f"🔄 Миграция {from_tier.name} → {to_tier.name}: перемещено {moved} файлов")
        return moved

    def run_lifecycle(self) -> dict:
        """
        Запускает полный цикл миграции:
        hot (30 дней) → warm (2 года) → cold (вечно)
        """
        stats = {}
        stats["hot_to_warm"] = self.migrate_by_age(
            self.hot.retention_days, self.hot, self.warm
        )
        stats["warm_to_cold"] = self.migrate_by_age(
            self.warm.retention_days, self.warm, self.cold
        )
        return stats

    def get_disk_usage(self) -> dict:
        """Возвращает использование диска для каждого tier'а."""
        usage = {}
        for tier in [self.hot, self.warm, self.cold]:
            total_size = sum(f.stat().st_size for f in tier.path.rglob("*") if f.is_file())
            usage[tier.name] = {
                "used_gb": round(total_size / (1024 ** 3), 2),
                "max_gb": tier.max_size_gb,
                "percent": round((total_size / tier.max_size_bytes) * 100, 1) if tier.max_size_bytes > 0 else 0,
                "path": str(tier.path),
            }
        return usage

    def check_health(self) -> list[str]:
        """Проверяет здоровье хранилища. Возвращает список предупреждений."""
        warnings = []
        for tier in [self.hot, self.warm, self.cold]:
            if not tier.path.exists():
                warnings.append(f"❌ Tier '{tier.name}' не существует: {tier.path}")
                continue

            usage = self.get_disk_usage()[tier.name]
            if usage["percent"] > 90:
                warnings.append(f"⚠️  Tier '{tier.name}' заполнен на {usage['percent']}%")
            if not os.access(tier.path, os.W_OK):
                warnings.append(f"❌ Нет прав на запись в tier '{tier.name}'")

        return warnings


# Для os.access
import os


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    # Пример использования
    tiers = [
        TierConfig("hot", Path("/tmp/joi_test/hot"), max_size_gb=1, retention_days=1),
        TierConfig("warm", Path("/tmp/joi_test/warm"), max_size_gb=5, retention_days=30),
        TierConfig("cold", Path("/tmp/joi_test/cold"), max_size_gb=10, retention_days=-1),
    ]

    manager = TierManager(tiers)
    print("Использование диска:", manager.get_disk_usage())
