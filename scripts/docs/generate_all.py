#!/usr/bin/env python3
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
REQUIRED = ["index.md", "architecture/overview.md", "guides/deployment.md", "guides/memory-setup.md", "reference/naming.md", "reference/prompts.md", "changelog.md"]
missing = [p for p in REQUIRED if not (DOCS / p).exists()]
if missing:
    print("❌ Отсутствуют страницы:", missing)
    sys.exit(1)
print("✅ Документация Joi на месте")
