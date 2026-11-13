#!/usr/bin/env bash
set -euo pipefail

MEMORY_ROOT="${JOI_MEMORY_ROOT:-/mnt/joi_memory}"
MODELS_ROOT="${JOI_MODELS_ROOT:-/opt/joi_models}"

echo "🔒 Хранилище памяти Joi"
echo "   память: $MEMORY_ROOT"
echo "   модели: $MODELS_ROOT"

for root in "$MEMORY_ROOT" "$MODELS_ROOT"; do
  if [[ ! -d "$root" ]]; then
    sudo mkdir -p "$root"
    sudo chown -R "$USER:$USER" "$root"
  fi
done

mkdir -p "$MEMORY_ROOT"/{hot/{index,cache,logs},warm/{dialogs,photos},cold/{audio,video,backups}}
mkdir -p "$MODELS_ROOT"/{whisper,piper,embeddings,ollama,lora}

chmod -R 700 "$MEMORY_ROOT"
chmod -R 755 "$MODELS_ROOT"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -e "$PROJECT_ROOT/memory" ]]; then
  ln -s "$MEMORY_ROOT" "$PROJECT_ROOT/memory"
  echo "✅ симлинк memory → $MEMORY_ROOT"
fi

echo "✅ Готово. Права на память: 700"
