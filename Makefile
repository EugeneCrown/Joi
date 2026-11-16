.PHONY: help install docs docs-serve naming check test storage brand prompts

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

VENV := .venv

install: venv
	$(VENV)/bin/pip install -e ".[dev]"
	$(VENV)/bin/pre-commit install


venv:
	python -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip

brand:
	PYTHONPATH=server python -c "from joi.core.branding import IDENTITY; print(IDENTITY)"

prompts:
	PYTHONPATH=server python -m joi.core.prompt_manager

naming:
	bash scripts/check_naming.sh

docs:
	python scripts/docs/generate_all.py

docs-serve:
	mkdocs serve --dev-addr 127.0.0.1:8000

storage:
	bash scripts/setup_server_storage.sh

check: naming
	$(VENV)/bin/ruff check server/

test:
	pytest
