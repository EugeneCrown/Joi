.PHONY: help install docs docs-serve naming check test storage brand prompts deploy-prod

help: ## Show help (list available make targets)
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

VENV := .venv

install: venv ## Install project dependencies and pre-commit hooks
	$(VENV)/bin/pip install -e ".[dev]"
	$(VENV)/bin/pre-commit install


venv: ## Create virtual environment
	python -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip

brand: ## Show brand identity
	PYTHONPATH=server python -c "from joi.core.branding import IDENTITY; print(IDENTITY)"

prompts: ## Run prompt manager
	PYTHONPATH=server python -m joi.core.prompt_manager

naming: ## Check naming conventions
	bash scripts/check_naming.sh

docs: ## Generate documentation
	python scripts/docs/generate_all.py

docs-serve: ## Serve documentation locally
	mkdocs serve --dev-addr 127.0.0.1:8000

storage: ## Setup server storage
	bash scripts/setup_server_storage.sh

check: naming

install-toolchain:
	@bash scripts/install_toolchain.sh

setup-voice-server:
	@bash scripts/setup_voice_on_server.sh ## Run linters (ruff) on server code
	$(VENV)/bin/ruff check server/

test: ## Run unit tests with pytest
	pytest

deploy-prod: ## Deploy code to production server
	@bash scripts/push_to_server.sh
