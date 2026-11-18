#!/usr/bin/env bash
set -euo pipefail

# Проверяем наличие cloudflared
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "⚠️ cloudflared не установлен. Установите его согласно https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  exit 1
fi

# Запускаем туннель с конфигом из директории cloudflare
# Путь относительно текущего каталога скрипта
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_PATH="$SCRIPT_DIR/../cloudflare/tunnel.yml"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "⚠️ Конфиг туннеля не найден: $CONFIG_PATH"
  exit 1
fi

echo "🚀 Запускаем Cloudflare Tunnel..."
cloudflared tunnel run $(grep '^tunnel:' "$CONFIG_PATH" | cut -d' ' -f2) --config "$CONFIG_PATH"
