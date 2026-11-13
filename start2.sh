# 1. Создаем скрипт завершения
cat > finish_joi.sh << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Завершаем настройку и заливаем на GitHub..."

# 1. Досоздаем недостающую документацию
mkdir -p docs/reference docs/guides docs/architecture scripts/docs

cat > docs/reference/naming.md << 'EOF'
# 🪪 Нейминг проекта
Единое имя ассистента — **Joi**, по-русски — **«Джой»**.
`config/agent.yaml` — единый источник истины.
EOF

cat > docs/reference/prompts.md << 'EOF'
# 🧠 Промпты Joi
Промпты хранятся в Git: `config/prompts/`. Шаблонизатор — Jinja2.
Автоматические переменные: `{{ agent_name }}`, `{{ user_name }}`, `{{ current_time }}`.
EOF

cat > docs/guides/memory-setup.md << 'EOF'
# 💾 Память Joi
Многоуровневая система: Hot (NVMe) / Warm (SSD) / Cold (HDD).
Данные никогда не удаляются (`never_delete: true`), только мигрируют.
EOF

cat > docs/guides/deployment.md << 'EOF'
# 🖥️ Деплой Joi
1. `git clone https://github.com/EugeneCrown/Joi.git /opt/joi`
2. `cd /opt/joi && ./scripts/setup_server_storage.sh`
3. `pip install -e .`
EOF

cat > docs/guides/voice-pipeline.md << 'EOF'
# 🎙️ Голосовой пайплайн
Микрофон → VAD → STT → LLM → нормализация → TTS → динамик.
Имя в тексте: `Joi`, в озвучке: `Джой` (благодаря `text_normalizer.py`).
EOF

cat > docs/architecture/overview.md << 'EOF'
# 🏗️ Архитектура Joi
Ключевые модули: `branding`, `prompt_manager`, `voice`, `memory`, `tier_manager`, `llm.router`.
EOF

cat > docs/index.md << 'EOF'
# Joi (Джой) 🧠
Персональный ИИ-ассистент на своём сервере с вечной памятью и голосовым управлением.
EOF

cat > docs/changelog.md << 'EOF'
# История изменений
## [unreleased]
- **Refactor**: Единое имя Joi (Джой). Пакет переименован из `klava` в `joi`.
- **Feature**: Многоуровневая память Hot/Warm/Cold с `never_delete=true`.
- **Feature**: Нормализация имени для TTS (Joi → Джой).
EOF

cat > mkdocs.yml << 'EOF'
site_name: Joi (Джой)
repo_url: https://github.com/EugeneCrown/Joi
theme:
  name: material
  language: ru
nav:
  - Главная: index.md
  - Архитектура: architecture/overview.md
  - Руководства:
      - Деплой: guides/deployment.md
      - Память: guides/memory-setup.md
      - Голос: guides/voice-pipeline.md
  - Справочники:
      - Нейминг: reference/naming.md
      - Промпты: reference/prompts.md
  - Изменения: changelog.md
EOF

cat > README.md << 'EOF'
# Joi (Джой) 🧠
Персональный ИИ-ассистент на своём сервере.
**Имя:** `Joi`, произносится «Джой». Источник — `config/agent.yaml`.
EOF

cat > scripts/docs/generate_all.py << 'EOF'
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
EOF
chmod +x scripts/docs/generate_all.py

# 2. Git commit и push
echo "📦 Коммит изменений..."
git add -A
git status --short

if git diff --cached --quiet; then
  echo "ℹ️ Изменений для коммита нет (всё уже залито)."
else
  git commit -m "refactor!: unify assistant name to Joi (Джой) and complete docs

- Renamed package klava -> joi
- Single source of identity: config/agent.yaml
- Prompts use {{ agent_name }} variables
- Added memory tiers (hot/warm/cold) with never_delete=true
- Added TTS normalization (Joi -> Джой)
- Completed MkDocs documentation structure"

  echo "📤 Отправка на GitHub..."
  # Настраиваем remote, если его нет
  git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/EugeneCrown/Joi.git
  
  # Получаем текущую ветку и пушим
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push -u origin "$BRANCH"
  
  echo "✅ Успешно залито в https://github.com/EugeneCrown/Joi"
fi

echo "🎉 Готово!"
SCRIPT_EOF

# 2. Делаем его исполняемым и запускаем
chmod +x finish_joi.sh
./finish_joi.sh

# 3. Удаляем временный скрипт
rm finish_joi.sh
