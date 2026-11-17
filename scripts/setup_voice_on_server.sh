#!/usr/bin/env bash
set -e

# Установка зависимостей для голосового стека на сервере
# Требуются sudo права для apt-get; если скрипт запускается без sudo, он попросит пароль.

echo "Обновляем пакетный индекс..."
sudo apt-get update -y

echo "Устанавливаем необходимые системные пакеты..."
sudo apt-get install -y python3-pip python3-distutils python3.10 python3.10-venv git build-essential cmake libportaudio2 ffmpeg

# Устанавливаем Porcupine (pvporcupine) – библиотека wake‑word
echo "Устанавливаем pvporcupine..."
# Создаём виртуальное окружение, если его ещё нет
VENV_DIR="$HOME/.venv/pv"
if [ ! -d "$VENV_DIR" ]; then
echo "Создаю venv в $VENV_DIR ..."
python3.10 -m venv "$VENV_DIR"
fi
# Активируем venv
source "$VENV_DIR/bin/activate"
# Обновляем pip, setuptools и wheel внутри venv
python -m pip install --upgrade pip setuptools wheel
# Устанавливаем pvporcupine внутри venv
python -m pip install pvporcupine

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
  if [ -f requirements.txt ]; then python -m pip install -r requirements.txt; fi
  echo "Установка Piper..."
  python -m pip install .
  cd ..
else
  echo "Piper уже существует, установка пропущена."
fi

echo "Голосовой стек успешно установлен на сервере."
