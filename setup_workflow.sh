#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Фиксируем workflow: ноутбук → GitHub → сервер"
echo "   Код на сервере: /home/grebenkine/Joi/"
echo "   Память на сервере: /memory/"

[[ -d .git ]] || { echo "❌ Запусти из корня репозитория Joi"; exit 1; }

# ----------------------------------------------------------------------------
# 1. scripts/setup_server.sh — первичная настройка сервера (один раз)
# ----------------------------------------------------------------------------
cat > scripts/setup_server.sh << 'SETUP_EOF'
#!/usr/bin/env bash
# Первичная настройка сервера Joi. Запускать ОДИН РАЗ.
set -euo pipefail

JOI_HOME="${JOI_HOME:-/home/grebenkine/Joi}"
JOI_MEMORY="${JOI_MEMORY:-/memory}"
JOI_MODELS="${JOI_MODELS:-/home/grebenkine/joi_models}"
USER_NAME="${USER_NAME:-grebenkine}"

echo "🔧 Первичная настройка сервера Joi"
echo "   Код:    $JOI_HOME"
echo "   Память: $JOI_MEMORY"
echo "   Модели: $JOI_MODELS"
echo "   Пользователь: $USER_NAME"

# 1. Системные зависимости
echo "📦 Устанавливаем системные пакеты..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip git curl ffmpeg

# 2. Ollama (если ещё не установлена)
if ! command -v ollama >/dev/null 2>&1; then
    echo "🦙 Устанавливаем Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    sudo systemctl enable --now ollama
    sleep 3
    echo "📥 Скачиваем fallback-модель qwen2.5:1.5b..."
    ollama pull qwen2.5:1.5b
else
    echo "✅ Ollama уже установлена"
fi

# 3. Структура памяти (HDD /memory)
echo "📁 Создаём структуру памяти в $JOI_MEMORY..."
sudo mkdir -p "$JOI_MEMORY"/{hot/{index,cache,logs},warm/{dialogs,photos,documents},cold/{audio,video,backups,datasets}}
sudo chown -R "$USER_NAME:$USER_NAME" "$JOI_MEMORY"
sudo chmod -R 700 "$JOI_MEMORY"

# 4. Папка для моделей (если хотим хранить вне ~/.ollama)
mkdir -p "$JOI_MODELS"/{whisper,piper,embeddings,lora}

# 5. Python venv в папке проекта
echo "🐍 Создаём виртуальное окружение..."
cd "$JOI_HOME"
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"

# 6. .env из шаблона
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️  Заполни .env своими ключами: nano $JOI_HOME/.env"
fi

# 7. Systemd-сервис
echo "⚙️  Устанавливаем systemd-сервис..."
sudo cp scripts/joi.service /etc/systemd/system/joi.service
sudo sed -i "s|__JOI_HOME__|$JOI_HOME|g" /etc/systemd/system/joi.service
sudo sed -i "s|__USER_NAME__|$USER_NAME|g" /etc/systemd/system/joi.service
sudo systemctl daemon-reload
sudo systemctl enable joi
sudo systemctl start joi

# 8. Проверка
echo ""
echo "📊 Статус сервиса:"
sudo systemctl status joi --no-pager || true

echo ""
echo "🎉 Первичная настройка завершена!"
echo ""
echo "Полезные команды:"
echo "  sudo systemctl status joi   # статус"
echo "  sudo journalctl -u joi -f   # логи"
echo "  sudo systemctl restart joi  # перезапуск"
echo "  ollama ps                   # запущенные модели"
SETUP_EOF
chmod +x scripts/setup_server.sh

# ----------------------------------------------------------------------------
# 2. scripts/deploy.sh — обновление после git pull
# ----------------------------------------------------------------------------
cat > scripts/deploy.sh << 'DEPLOY_EOF'
#!/usr/bin/env bash
# Быстрый деплой после git pull. Обновляет зависимости и перезапускает сервис.
set -euo pipefail

JOI_HOME="${JOI_HOME:-/home/grebenkine/Joi}"
cd "$JOI_HOME"

echo "🚀 Деплой обновлений..."

# 1. Подтягиваем свежие изменения
git pull origin main

# 2. Обновляем зависимости
if [ -f .venv/bin/activate ]; then
    source .venv/bin/activate
    pip install -q -e ".[dev]"
    echo "✅ Зависимости обновлены"
else
    echo "⚠️  venv не найден. Запусти сначала scripts/setup_server.sh"
    exit 1
fi

# 3. Перезапускаем сервис
if systemctl is-active --quiet joi; then
    sudo systemctl restart joi
    echo "✅ Сервис Joi перезапущен"
else
    sudo systemctl start joi
    echo "✅ Сервис Joi запущен"
fi

echo ""
echo "📊 Статус:"
sudo systemctl status joi --no-pager | head -n 15
DEPLOY_EOF
chmod +x scripts/deploy.sh

# ----------------------------------------------------------------------------
# 3. scripts/joi.service — systemd unit
# ----------------------------------------------------------------------------
cat > scripts/joi.service << 'SERVICE_EOF'
[Unit]
Description=Joi — Personal AI Assistant
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=__USER_NAME__
WorkingDirectory=__JOI_HOME__
Environment="PATH=__JOI_HOME__/.venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=__JOI_HOME__/.env
ExecStart=__JOI_HOME__/.venv/bin/uvicorn joi.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/memory __JOI_HOME__
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# ----------------------------------------------------------------------------
# 4. server/joi/main.py — минимальный FastAPI-скелет
# ----------------------------------------------------------------------------
mkdir -p server/joi
cat > server/joi/main.py << 'MAIN_EOF'
"""Точка входа FastAPI-приложения Joi."""
from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from joi.core.branding import IDENTITY


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown хуки."""
    print(f"🚀 [{IDENTITY.name}] запускается (v{IDENTITY.version})")
    print(f"   Пользователь: {IDENTITY.user_name}")
    yield
    print(f"👋 [{IDENTITY.name}] остановлена")


app = FastAPI(
    title="Joi API",
    description="Персональный ИИ-ассистент с вечной памятью",
    version=IDENTITY.version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    """Корневой эндпоинт — проверка живости."""
    return {
        "agent": IDENTITY.name,
        "agent_ru": IDENTITY.name_ru,
        "version": IDENTITY.version,
        "user": IDENTITY.user_name,
        "time": datetime.now().isoformat(),
        "status": "ok",
    }


@app.get("/health")
async def health():
    """Health-check для systemd и мониторинга."""
    return {"status": "ok", "agent": IDENTITY.name}
MAIN_EOF

# ----------------------------------------------------------------------------
# 5. Обновляем config/server.yaml — реальные пути
# ----------------------------------------------------------------------------
cat > config/server.yaml << 'YAML_EOF'
# ============================================================================
# Сервер Joi
# ============================================================================
agent_config: "config/agent.yaml"

server:
  host: "0.0.0.0"
  port: 8000
  debug: false
  log_level: "INFO"

# ----------------------------------------------------------------------------
# Пути (реальный сервер: Ubuntu, пользователь grebenkine)
# ----------------------------------------------------------------------------
paths:
  code: "/home/grebenkine/Joi"
  memory: "/memory"
  models: "/home/grebenkine/joi_models"

storage:
  root_path: "/memory"
  tiers:
    hot:
      path: "/memory/hot"
      device: "nvme"
      max_size_gb: 50
      retention_days: 30
    warm:
      path: "/memory/warm"
      device: "sata_ssd"
      max_size_gb: 100
      retention_days: 730
    cold:
      path: "/memory/cold"
      device: "hdd"
      max_size_gb: 150
      retention_days: -1
  index:
    backend: "lancedb"
    path: "/memory/hot/index"
    embedding_dim: 384
  lifecycle:
    migration_cron: "0 3 * * *"
    never_delete: true
  privacy:
    permissions: "0700"
    sync_to_git: false

models:
  root_path: "/home/grebenkine/joi_models"
  whisper: "base-int8"
  embedding: "all-MiniLM-L6-v2"
  tts: "ru_RU-ruslan-medium"
  local_llm: "qwen2.5:1.5b"
  router_llm: "qwen2.5:1.5b"

cloud:
  proxyapi_endpoint: "https://api.proxyapi.ru/v1"
  timeout_seconds: 30
  fallback_to_local: true

prompts:
  dir: "config/prompts"
  cache_enabled: true
  hot_reload: false
YAML_EOF

# ----------------------------------------------------------------------------
# 6. Обновляем scripts/setup_server_storage.sh (старый, но оставим рабочим)
# ----------------------------------------------------------------------------
cat > scripts/setup_server_storage.sh << 'STORAGE_EOF'
#!/usr/bin/env bash
# Создаёт структуру памяти Joi на сервере.
set -euo pipefail

MEMORY_ROOT="${JOI_MEMORY:-/memory}"
MODELS_ROOT="${JOI_MODELS:-/home/grebenkine/joi_models}"

echo "🔒 Хранилище памяти Joi"
echo "   память: $MEMORY_ROOT"
echo "   модели: $MODELS_ROOT"

sudo mkdir -p "$MEMORY_ROOT"/{hot/{index,cache,logs},warm/{dialogs,photos,documents},cold/{audio,video,backups,datasets}}
sudo mkdir -p "$MODELS_ROOT"/{whisper,piper,embeddings,ollama,lora}

sudo chown -R "$USER:$USER" "$MEMORY_ROOT" "$MODELS_ROOT"
sudo chmod -R 700 "$MEMORY_ROOT"
sudo chmod -R 755 "$MODELS_ROOT"

echo "✅ Готово"
STORAGE_EOF
chmod +x scripts/setup_server_storage.sh

# ----------------------------------------------------------------------------
# 7. Обновляем docs/guides/deployment.md
# ----------------------------------------------------------------------------
cat > docs/guides/deployment.md << 'DEPLOY_DOC_EOF'
# 🖥️ Деплой Joi на сервер

## Архитектура рабочего процесса

```text
┌─────────────────┐      git push      ┌──────────┐      git pull      ┌────────────────────┐
│  Ноутбук ASUS   │ ─────────────────► │  GitHub  │ ─────────────────► │  Сервер (Ubuntu)   │
│  Cursor / Zed   │                    │  Joi     │                    │  /home/grebenkine/ │
└─────────────────┘                    └──────────┘                    │         Joi/       │
                                                                       └────────────────────┘
                                                                                    │
                                                                                    ▼
                                                                           /memory (HDD 300GB)
