"""Подготовка текста ответа Joi к синтезу речи (TTS)."""
from __future__ import annotations

import re

from joi.core.branding import IDENTITY

_MD_PATTERNS = (
    (re.compile(r"```.*?```", re.S), " "),
    (re.compile(r"`([^`]+)`"), r"\1"),
    (re.compile(r"\*\*([^*]+)\*\*"), r"\1"),
    (re.compile(r"\*([^*]+)\*"), r"\1"),
    (re.compile(r"^\s{0,3}#{1,6}\s*", re.M), ""),
    (re.compile(r"!?\[([^\]]*)\]\([^)]*\)"), r"\1"),
    (re.compile(r"^\s*[-*+]\s+", re.M), ""),
    (re.compile(r"\s+"), " "),
)


def normalize_for_tts(text: str, strip_markdown: bool = True) -> str:
    result = text
    if strip_markdown:
        for pattern, repl in _MD_PATTERNS:
            result = pattern.sub(repl, result)
    result = re.sub(r"\bJoi\b", IDENTITY.tts_name, result, flags=re.IGNORECASE)
    return result.strip()


if __name__ == "__main__":
    sample = "**Joi** готова. Я обновила `config/agent.yaml`."
    print(normalize_for_tts(sample))
