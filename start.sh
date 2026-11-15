#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Обновление конфигурации под реальное железо..."

# 1. Обновляем пути в config/server.yaml (простая замена)
if [ -f config/server.yaml ]; then
    sed -i 's|/mnt/joi_memory|/memory|g' config/server.yaml
    echo "✅ config/server.yaml обновлен (путь к памяти: /memory)"
else
    echo "⚠️ config/server.yaml не найден, создаем базовый..."
    mkdir -p config
    echo -e "storage:\n  root_path: \"/memory\"" > config/server.yaml
fi

# 2. Создаем документацию по железу (используем уникальный маркер HARDWARE_EOF)
mkdir -p docs/reference
cat > docs/reference/hardware.md << 'HARDWARE_EOF'
# 🖥️ Спецификации сервера Joi

| Компонент | Спецификация | Примечание для Joi |
|-----------|--------------|---------------------|
| **CPU** | Intel Core i3-2120 @ 3.30GHz (2 ядра, 4 потока) | Инференс LLM медленный (1-3 токена/сек). |
| **RAM** | 8 ГБ | Локальные модели не должны занимать > 2 ГБ ОЗУ. |
| **GPU** | Отсутствует | Весь инференс (STT, LLM, TTS) на CPU. |
| **Диск системы** | 238.5 ГБ NVMe | ОС, код приложения, кэш. |
| **Диск памяти** | 298.1 ГБ HDD (`sda`) | Смонтирован в `/memory`. Долгосрочная память. |

## Стратегия моделей
1. **Основной:** Облачный API (`proxyapi.ru`).
2. **Fallback:** `qwen2.5:1.5b` (Ollama, ~1.2 ГБ ОЗУ).
3. **STT:** `faster-whisper` (`base-int8` или `tiny-int8`) + жесткий VAD.
HARDWARE_EOF
echo "✅ docs/reference/hardware.md создан"

# 3. Git commit и push
echo "📦 Коммит изменений..."
git add -A

if git diff --cached --quiet; then
  echo "ℹ️ Изменений для коммита нет (всё уже актуально)."
else
  git commit -m "chore: update hardware specs and memory path to /memory

- config/server.yaml: memory root is now '/memory'
- Added docs/reference/hardware.md (i3-2120, 8GB RAM, no GPU)
- Confirmed local fallback: qwen2.5:1.5b"

  echo "📤 Отправка на GitHub..."
  git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/EugeneCrown/Joi.git
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push -u origin "$BRANCH"
  echo "✅ Успешно залито в https://github.com/EugeneCrown/Joi"
fi

echo "🎉 Готово!"
