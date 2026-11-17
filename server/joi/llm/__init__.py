"""Unified LLM interface.

- Если доступен облачный API (proxyapi.ru), запрос отправляется туда.
- При ошибке или недоступности облака, если ``fallback_to_local`` установлен в ``true`` (по умолчанию), запрос переадресуется в локальную LLM через Ollama.
"""

import json
import pathlib
import urllib.request
import urllib.error
import yaml

# Путь к корню проекта и файлу конфигурации
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[4]
CONFIG_PATH = PROJECT_ROOT / "config" / "server.yaml"


def _load_config():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


_CONFIG = _load_config()


def _cloud_chat(prompt: str) -> str:
    """Отправить запрос к облачному endpoint ``proxyapi.ru``.

    Ожидается, что API принимает JSON‑тело ``{"prompt": <str>}`` и возвращает
    JSON с полем ``response``.  Ошибки пробрасываются наружу.
    """
    endpoint = _CONFIG.get("cloud", {}).get("proxyapi_endpoint")
    if not endpoint:
        raise RuntimeError("Cloud endpoint not configured")
    payload = {"prompt": prompt}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(
            req, timeout=_CONFIG.get("cloud", {}).get("timeout_seconds", 30)
        ) as resp:
            result = json.load(resp)
            return result.get("response", "")
    except urllib.error.URLError as e:
        raise RuntimeError(f"Cloud LLM request failed: {e}")


def chat(prompt: str) -> str:
    """Единый метод получения ответа от LLM.

    1️⃣ Пытаемся обратиться к облачному API (если настроено).
    2️⃣ При ошибке и если ``fallback_to_local`` включён – переключаемся
       на локальную модель через Ollama (модуль :mod:`.ollama`).
    """
    # Попытка обращения к облаку
    cloud_cfg = _CONFIG.get("cloud", {})
    if cloud_cfg.get("proxyapi_endpoint"):
        try:
            return _cloud_chat(prompt)
        except Exception:
            if not cloud_cfg.get("fallback_to_local", True):
                raise
    # Локальная модель через Ollama
    from .ollama import chat as local_chat

    return local_chat(prompt)
