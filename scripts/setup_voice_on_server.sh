#!/usr/bin/env bash
set -e

# Установка зависимостей для голосового стека на сервере
# Требуются sudo права для apt-get; если скрипт запускается без sudo, он попросит пароль.

echo "Обновляем пакетный индекс..."
sudo apt-get update -y

echo "Устанавливаем необходимые системные пакеты..."
sudo apt-get install -y python3-pip git build-essential cmake libportaudio2 ffmpeg

# Устанавливаем Porcupine (pvporcupine) – библиотека wake‑word
echo "Устанавливаем pvporcupine..."
pip3 install --user pvporcupine

# Клонируем и собираем whisper.cpp (для STT)
if [ ! -d "whisper.cpp" ]; then
  echo "Клонирование whisper.cpp..."
  git clone https://github.com/ggerganov/whisper.cpp.git
  cd whisper.cpp
  echo "Сборка whisper.cpp..."
  make -j$(nproc)
  cd ..
else
  echo "whisper.cpp уже существует, сборка отключена."
fi

# Клонируем и устанавливаем Piper (TTS)
if [ ! -d "piper" ]; then
  echo "Клонирование Piper TTS..."
  git clone https://github.com/rhasspy/piper.git
  cd piper
  echo "Установка требований Piper..."
  pip3 install --user -r requirements.txt
  echo "Установка Piper..."
  pip3 install --user .
  cd ..
else
  echo "Piper уже существует, установка пропущена."
fi

echo "Голосовой стек успешно установлен на сервере."
