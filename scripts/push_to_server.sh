#!/usr/bin/env bash
set -euo pipefail

# Добавляем удалённый репозиторий prod, если его ещё нет
if ! git remote get-url prod >/dev/null 2>&1; then
  git remote add prod "ssh://grebenkine@192.168.0.78/home/grebenkine/Joi"
  echo "✅ Добавлен git remote 'prod' → ssh://grebenkine@192.168.0.78/home/grebenkine/Joi"
fi

# Пушим изменения
echo "🚀 Пушим изменения в продакшн..."
git push prod main

# Пост‑деплой на сервере
echo "🔧 Выполняем пост‑деплой на сервере..."
ssh grebenkine@192.168.0.78 <<'EOF'
  cd /home/grebenkine/Joi
  # Создаём/обновляем виртуальное окружение и зависимости
  if [ -d ".venv" ]; then
    ./.venv/bin/pip install -e ".[dev]"
  else
    python -m venv .venv
    ./.venv/bin/pip install -e ".[dev]"
  fi
  # Копируем юнит‑файлы в /tmp (без sudo)
  cp scripts/joi.service /tmp/joi.service
  cp scripts/joi-cloudflare.service /tmp/joi-cloudflare.service
  cp scripts/joi-cloudflare.env /tmp/joi-cloudflare.env

  # Перемещаем в системный каталог и перезагружаем systemd (sudo‑команды, уже разрешённые без пароля)
  sudo -n mv /tmp/joi.service /etc/systemd/system/joi.service
  sudo -n mv /tmp/joi-cloudflare.env /etc/default/joi-cloudflare
  sudo -n systemctl daemon-reload
  sudo -n systemctl enable joi.service
  sudo -n systemctl enable joi-cloudflare.service
  sudo -n mv /tmp/joi-cloudflare.service /etc/systemd/system/joi-cloudflare.service
  sudo -n systemctl daemon-reload
  sudo -n systemctl start joi-cloudflare.service || echo "⚠️ Не удалось запустить cloudflared tunnel"

  # Старт/перезапуск сервиса
  if systemctl is-active --quiet joi.service; then
    sudo -n systemctl restart joi.service || echo "⚠️ Не удалось перезапустить joi.service"
  else
    sudo -n systemctl start joi.service || echo "⚠️ Не удалось запустить joi.service"
  fi
EOF

echo "✅ Деплой завершён"
