"""Simple wrapper for local Ollama LLM.

The project configuration (`config/server.yaml`) defines the local model name
under ``models.local_llm`` (e.g. ``qwen2.5:1.5b``).  Ollama exposes a HTTP API at
``http://localhost:11434/api/generate``.  This module provides a minimal
``chat(prompt: str) -> str`` function that calls the local Ollama server.
"""

import json
import pathlib
import urllib.request
import urllib.error
import urllib.parse

# Путь к корню репозитория (от папки ``joi/llm`` поднимаемся вверх до ``Joi``)
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[4]
CONFIG_PATH = PROJECT_ROOT / "config" / "server.yaml"


def _load_config():
    import yaml

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


_CONFIG = _load_config()
_MODEL_NAME = _CONFIG.get("models", {}).get("local_llm", "qwen2.5:1.5b")
_OLLAMA_URL = "http://localhost:11434/api/generate"


def chat(prompt: str) -> str:
    """Отправить ``prompt`` в Ollama и вернуть сгенерированный ответ.

    Параметр ``stream`` отключён (``False``), чтобы сервер сразу вернул весь
    ответ в поле ``response``.
    """
    payload = {
        "model": _MODEL_NAME,
        "prompt": prompt,
        "stream": False,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        _OLLAMA_URL, data=data, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.load(resp)
            # Ollama возвращает поле "response" со сгенерированным текстом
            return result.get("response", "")
    except urllib.error.URLError as e:
        # Прокидываем исключение выше – вызывающий код решит, как реагировать
        raise RuntimeError(f"Failed to connect to Ollama at {_OLLAMA_URL}: {e}")
