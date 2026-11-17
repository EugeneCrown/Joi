#!/usr/bin/env bash
set -euo pipefail

# Добавляем удалённый репозиторий prod, если его ещё нет
if ! git remote get-url prod >/dev/null 2>&1; then
  git remote add prod "ssh://grebenkine@192.168.0.78/home/grebenkine/Joi"
  echo "✅ Добавлен git remote 'prod' → ssh://grebenkine@192.168.0.78/home/grebenkine/Joi"
fi

echo "🚀 Пушим изменения в продакшн..."
git push prod main

echo "🔧 Выполняем пост‑деплой на сервере..."
ssh grebenkine@192.168.0.78 <<'EOF'
  cd /home/grebenkine/Joi
  # Обновляем зависимости (если виртуальное окружение уже создано)
  if [ -d ".venv" ]; then
    ./.venv/bin/pip install -e ".[dev]"
  fi
  # Копируем/обновляем systemd‑юнит
  sudo cp scripts/joi.service /etc/systemd/system/joi.service
  sudo systemctl daemon-reload
  sudo systemctl enable joi.service
  # Перезапуск (если уже запущен) или старт
  if systemctl is-active --quiet joi.service; then
    sudo systemctl restart joi.service || echo "⚠️ Не удалось перезапустить systemd сервис joi"
  else
    sudo systemctl start joi.service || echo "⚠️ Не удалось запустить systemd сервис joi"
  fi
EOF

echo "✅ Деплой завершён"
