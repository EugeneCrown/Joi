# 🪪 Нейминг проекта

Единое имя ассистента — **Joi**, по-русски — **«Джой»**.

| Сущность | Значение |
|----------|----------|
| Имя в тексте, логах, API | `Joi` |
| Произношение (TTS) | `Джой` |
| Python-пакет | `joi` |
| Репозиторий | `EugeneCrown/Joi` |
| Переменные окружения | `JOI_*` |
| Память на сервере | `/mnt/joi_memory/{hot,warm,cold}` |

## Единый источник

`config/agent.yaml` — имя, произношение, wake-words, личность.

```python
from joi.core.branding import IDENTITY
print(IDENTITY.name)  # Joi
print(IDENTITY.name_ru)  # Джой
