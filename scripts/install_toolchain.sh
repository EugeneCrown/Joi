#!/usr/bin/env bash
set -e
# Установка Arduino CLI в домашний каталог пользователя
INSTALL_DIR="$HOME/bin"
mkdir -p "$INSTALL_DIR"
# Скачивание и установка Arduino CLI
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh -s -- --install-dir "$INSTALL_DIR"
# Добавление в PATH для текущей сессии
export PATH="$PATH:$INSTALL_DIR"
# Обновление индекса ядер и установка ESP32‑C6 core
arduino-cli core update-index
arduino-cli core install esp32:esp32@2.0.5
echo "Arduino CLI и ESP32 core успешно установлены в $INSTALL_DIR"
