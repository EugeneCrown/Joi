"""Многоуровневая память Joi: Hot / Warm / Cold."""
from __future__ import annotations

import logging
import os
import shutil
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class TierConfig:
    name: str
    path: Path
    max_size_gb: int
    retention_days: int

    @property
    def max_size_bytes(self) -> int:
        return self.max_size_gb * (1024 ** 3)


class TierManager:
    def __init__(self, tiers: list[TierConfig]) -> None:
        if len(tiers) != 3:
            raise ValueError("Ожидается 3 уровня: hot, warm, cold")
        self.hot, self.warm, self.cold = tiers
        self._ensure_dirs()

    @classmethod
    def from_config(cls, storage_cfg: dict) -> "TierManager":
        tiers = [
            TierConfig(
                name=name,
                path=Path(storage_cfg["tiers"][name]["path"]),
                max_size_gb=int(storage_cfg["tiers"][name].get("max_size_gb", 100)),
                retention_days=int(storage_cfg["tiers"][name].get("retention_days", -1)),
            )
            for name in ("hot", "warm", "cold")
        ]
        return cls(tiers)

    def _ensure_dirs(self) -> None:
        for tier in (self.hot, self.warm, self.cold):
            tier.path.mkdir(parents=True, exist_ok=True)
            logger.info("📁 [%s] %s", tier.name, tier.path)

    def migrate_by_age(self, days: int, source: TierConfig, target: TierConfig) -> int:
        if days is None or days < 0:
            return 0
        cutoff = datetime.now() - timedelta(days=days)
        moved = 0
        for path in source.path.rglob("*"):
            if not path.is_file():
                continue
            if "index" in path.relative_to(source.path).parts:
                continue
            if datetime.fromtimestamp(path.stat().st_mtime) >= cutoff:
                continue
            rel = path.relative_to(source.path)
            dest = target.path / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(dest))
            moved += 1
        logger.info("🔄 %s → %s: %d файлов", source.name, target.name, moved)
        return moved

    def run_lifecycle(self) -> dict[str, int]:
        return {
            "hot_to_warm": self.migrate_by_age(self.hot.retention_days, self.hot, self.warm),
            "warm_to_cold": self.migrate_by_age(self.warm.retention_days, self.warm, self.cold),
        }

    def get_disk_usage(self) -> dict[str, dict]:
        usage: dict[str, dict] = {}
        for tier in (self.hot, self.warm, self.cold):
            used = sum(f.stat().st_size for f in tier.path.rglob("*") if f.is_file())
            usage[tier.name] = {
                "path": str(tier.path),
                "used_gb": round(used / (1024 ** 3), 2),
                "max_gb": tier.max_size_gb,
                "percent": round(used / tier.max_size_bytes * 100, 1) if tier.max_size_bytes else 0.0,
            }
        return usage

    def check_health(self) -> list[str]:
        problems: list[str] = []
        usage = self.get_disk_usage()
        for tier in (self.hot, self.warm, self.cold):
            if not tier.path.exists():
                problems.append(f"❌ [{tier.name}] нет каталога {tier.path}")
                continue
            if not os.access(tier.path, os.W_OK):
                problems.append(f"❌ [{tier.name}] нет прав на запись")
            if usage[tier.name]["percent"] > 90:
                problems.append(f"⚠️ [{tier.name}] заполнен на {usage[tier.name]['percent']}%")
        return problems


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    base = Path("/tmp/joi_tiers_demo")
    tm = TierManager([
        TierConfig("hot", base / "hot", 1, 1),
        TierConfig("warm", base / "warm", 5, 30),
        TierConfig("cold", base / "cold", 10, -1),
    ])
    print(tm.get_disk_usage())
