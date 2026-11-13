#!/usr/bin/env bash
set -euo pipefail

LEGACY='klava|Klava|KLAVA|Клава|Клавы|Клаве|Клаву|Клавой'

if grep -rInE "$LEGACY" \
    --exclude-dir=.git --exclude-dir=.venv --exclude-dir=venv \
    --exclude-dir=node_modules --exclude-dir=site --exclude-dir=data \
    --exclude-dir=models --exclude-dir=memory --exclude-dir=.joi_backup \
    --exclude-dir=__pycache__ --exclude-dir=build --exclude-dir=dist \
    --exclude=naming.md --exclude=check_naming.sh --exclude=rename_to_joi.sh \
    . ; then
  echo ""
  echo "❌ Найдено старое имя. Актуальное: Joi (Джой)."
  exit 1
fi

echo "✅ Нейминг OK: везде Joi (Джой)"
