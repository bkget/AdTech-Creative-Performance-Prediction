# ==============================================================================
# AdTech Creative Performance Prediction - Makefile
# ==============================================================================
# Two clear jobs live here:
#   1. Local ML pipeline (DVC)      → produces data/processed/*, models/*, results/*
#   2. Docker container fleet        → Postgres, FastAPI, Airflow (which runs
#                                        dbt + serving verification end-to-end on
#                                        its own -- see orchestration/airflow_dag/).
# Manual dbt/db targets below are dev conveniences; the Airflow DAG is the
# source of truth for orchestration and always runs inside the same container.
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Virtual environment configuration
VENV ?= .venv
VENV_BIN := $(VENV)/bin
PYTHON := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
PYTEST := $(VENV_BIN)/pytest
DVC := $(VENV_BIN)/dvc

# Ensure .env exists before anything (incl. variable parsing below) reads it
ifeq ($(wildcard .env),)
    $(shell cp .env.example .env 2>/dev/null || true)
endif

# Database parameters, read once from .env for db-shell
DB_USER := $(shell grep -E '^(POSTGRES_USER|DB_USER)=' .env 2>/dev/null | head -n1 | cut -d '=' -f2)
DB_USER := $(if $(strip $(DB_USER)),$(DB_USER),postgres)
DB_NAME := $(shell grep -E '^(POSTGRES_DB|DB_NAME)=' .env 2>/dev/null | head -n1 | cut -d '=' -f2)
DB_NAME := $(if $(strip $(DB_NAME)),$(DB_NAME),adcreative_db)
DB_PASSWORD := $(shell grep -E '^(POSTGRES_PASSWORD|DB_PASSWORD)=' .env 2>/dev/null | head -n1 | cut -d '=' -f2)
DB_PASSWORD := $(if $(strip $(DB_PASSWORD)),$(DB_PASSWORD),postgres)
DB_PORT := $(shell grep -E '^POSTGRES_PORT=' .env 2>/dev/null | head -n1 | cut -d '=' -f2)
DB_PORT := $(if $(strip $(DB_PORT)),$(DB_PORT),5432)

# Detect docker-compose command (v2 or v1)
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null || echo "docker compose")

# Styling & Colors
BLUE   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RED    := \033[31m
RESET  := \033[0m
BOLD   := \033[1m

## -----------------------------------------------------------------------------
## Help & Discovery
## -----------------------------------------------------------------------------

.PHONY: help
help: ## Display this help menu
	@echo -e "\n${BOLD}${BLUE}AdTech Creative Performance Prediction — Automation CLI${RESET}\n"
	@echo -e "${YELLOW}Usage:${RESET} make ${GREEN}<target>${RESET}\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-20s${RESET} %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo -e "\n${BOLD}Quick Start:${RESET} ${GREEN}make setup && make up${RESET}   (then ${GREEN}make dvc-repro${RESET} once, to populate data/models)\n"

## -----------------------------------------------------------------------------
## Environment & Setup
## -----------------------------------------------------------------------------

$(VENV)/.installed: requirements.txt
	@echo -e "${YELLOW}Ensuring local virtual environment and dependencies are up to date...${RESET}"
	@test -d "$(VENV)" || python3 -m venv $(VENV)
	@$(PIP) install --upgrade pip -q
	@$(PIP) install -r requirements.txt -q
	@touch $(VENV)/.installed
	@echo -e "${GREEN}✓ Virtual environment & dependencies ready in $(VENV).${RESET}"

.PHONY: venv
venv: $(VENV)/.installed ## Create the virtual environment and install dependencies

.PHONY: setup
setup: init-env $(VENV)/.installed ## Initialize .env and install local dependencies (first-time setup)

.PHONY: init-env
init-env: ## Create .env from .env.example if not already present
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo -e "${GREEN}✓ .env file created.${RESET}"; \
	else \
		echo -e "${BLUE}ℹ .env already exists.${RESET}"; \
	fi

.PHONY: install
install: $(VENV)/.installed ## Install/update Python dependencies into the virtual environment

## -----------------------------------------------------------------------------
## Docker & Container Lifecycle
## -----------------------------------------------------------------------------

.PHONY: _service-urls
_service-urls:
	@echo -e "${BLUE}  • Airflow Orchestrator:${RESET}  http://localhost:8088  (admin / admin)"
	@echo -e "${BLUE}  • dbt Documentation:${RESET}     http://localhost:8089"
	@echo -e "${BLUE}  • Interactive Dashboard:${RESET} http://localhost:8000"
	@echo -e "${BLUE}  • Swagger API Docs:${RESET}      http://localhost:8000/docs"
	@echo -e "${BLUE}  • Health Check:${RESET}          http://localhost:8000/health"
	@echo -e "${BLUE}  • Database:${RESET}              localhost:$(DB_PORT)/$(DB_NAME) (user=$(DB_USER) password=$(DB_PASSWORD))\n"

.PHONY: _wait-ready
_wait-ready:
	@echo -e "${YELLOW}⏳ Waiting for Airflow and dbt docs to come online (this can take a few minutes on a cold start)...${RESET}"
	@i=0; until curl -sf http://localhost:8088/health >/dev/null 2>&1; do \
		i=$$((i+1)); \
		if [ $$i -gt 420 ]; then echo -e "\n${RED}✗ Timed out after 420s waiting for Airflow. This can happen on a slow first-time cold start (Airflow initializing its metadata DB). Check 'make logs-airflow', or just wait and re-check http://localhost:8088 in your browser.${RESET}"; exit 0; fi; \
		echo -n "."; sleep 1; \
	done; \
	echo -e "\n${GREEN}✓ Airflow is ready at http://localhost:8088${RESET}"
	@i=0; until curl -sf http://localhost:8089 >/dev/null 2>&1; do \
		i=$$((i+1)); \
		if [ $$i -gt 240 ]; then echo -e "\n${RED}✗ Timed out after 240s waiting for dbt docs. Check 'make logs-airflow', or just wait and re-check http://localhost:8089 in your browser.${RESET}"; exit 0; fi; \
		echo -n "."; sleep 1; \
	done; \
	echo -e "\n${GREEN}✓ dbt docs are ready at http://localhost:8089${RESET}"
	@echo ""

.PHONY: up
up: init-env ## Start all containers in detached mode (builds only if missing)
	@echo -e "${YELLOW}Starting container fleet (postgres, api, airflow)...${RESET}"
	$(DOCKER_COMPOSE) up -d
	@echo -e "${GREEN}✓ Containers launched.${RESET}"
	@$(MAKE) --no-print-directory _service-urls
	@$(MAKE) --no-print-directory _wait-ready

.PHONY: build
build: ## Build or rebuild Docker images without starting containers
	@echo -e "${YELLOW}Building Docker images...${RESET}"
	$(DOCKER_COMPOSE) build

.PHONY: up-build
up-build: init-env ## Force rebuild images, then start containers in detached mode
	@echo -e "${YELLOW}Rebuilding and starting container fleet...${RESET}"
	$(DOCKER_COMPOSE) up -d --build
	@echo -e "${GREEN}✓ Containers rebuilt and launched.${RESET}"
	@$(MAKE) --no-print-directory _service-urls
	@$(MAKE) --no-print-directory _wait-ready

.PHONY: down
down: ## Stop and remove all containers, networks, and ephemeral state
	@echo -e "${YELLOW}Stopping containers...${RESET}"
	$(DOCKER_COMPOSE) down
	@echo -e "${GREEN}✓ Containers stopped.${RESET}"

.PHONY: stop
stop: down ## Alias for 'make down'

.PHONY: restart
restart: down up ## Restart the full container stack

.PHONY: ps status
ps status: ## List running containers and health statuses
	$(DOCKER_COMPOSE) ps

.PHONY: logs
logs: ## Tail streaming logs from all running containers
	$(DOCKER_COMPOSE) logs -f

.PHONY: logs-api
logs-api: ## Tail logs from the API service
	$(DOCKER_COMPOSE) logs -f api

.PHONY: logs-db
logs-db: ## Tail logs from the PostgreSQL database
	$(DOCKER_COMPOSE) logs -f postgres

.PHONY: logs-airflow
logs-airflow: ## Tail logs from the Airflow orchestrator
	$(DOCKER_COMPOSE) logs -f airflow

## -----------------------------------------------------------------------------
## Database Administration
## -----------------------------------------------------------------------------

.PHONY: db-shell
db-shell: ## Open an interactive psql shell inside the running Postgres container
	@echo -e "${YELLOW}Connecting to adcreative_db via psql (User: $(DB_USER), DB: $(DB_NAME))...${RESET}"
	docker exec -it adcreative_db psql -U $(DB_USER) -d $(DB_NAME)

.PHONY: db-reset
db-reset: ## Hard reset the database volume and recreate it (wipes all data)
	@echo -e "${RED}Resetting PostgreSQL volume and restarting adcreative_db...${RESET}"
	$(DOCKER_COMPOSE) down -v
	$(DOCKER_COMPOSE) up -d postgres
	@echo -e "${GREEN}✓ Clean database restarted.${RESET}"

## -----------------------------------------------------------------------------
## ML Pipeline & DVC (local, produces the artifacts Airflow/API read)
## -----------------------------------------------------------------------------

.PHONY: dvc-repro
dvc-repro: $(VENV)/.installed ## Reproduce the DVC pipeline: vision → features → benchmark → train
	@echo -e "${YELLOW}Executing DVC pipeline (vision → features → benchmark → train)...${RESET}"
	PATH=$(VENV_BIN):$$PATH $(DVC) repro
	@echo -e "${GREEN}✓ DVC pipeline reproduction complete.${RESET}"

.PHONY: dvc-metrics
dvc-metrics: $(VENV)/.installed ## Display model evaluation metrics tracked by DVC
	@echo -e "${YELLOW}DVC Evaluation Metrics:${RESET}"
	$(DVC) metrics show

.PHONY: dvc-status
dvc-status: $(VENV)/.installed ## Check DVC pipeline stage status and data cache
	$(DVC) status

.PHONY: run-pipeline
run-pipeline: $(VENV)/.installed ## Run the ML pipeline directly with the local venv (bypasses DVC caching)
	@echo -e "${YELLOW}Running complete ML pipeline...${RESET}"
	$(PYTHON) -m src.pipeline.run_all
	@echo -e "${GREEN}✓ ML pipeline executed successfully.${RESET}"

.PHONY: run-pipeline-docker
run-pipeline-docker: ## Run the ML pipeline in a one-off container (no local Python/venv needed)
	$(DOCKER_COMPOSE) run --rm pipeline

## -----------------------------------------------------------------------------
## dbt (manual dev conveniences -- Airflow already runs these automatically
## as part of adcreative_end_to_end_pipeline, always inside this same container)
## -----------------------------------------------------------------------------

DBT_IN_AIRFLOW = docker exec adcreative_airflow bash -c 'export DBT_LOG_PATH=/tmp/dbt/logs DBT_TARGET_PATH=/tmp/dbt/target && cd /opt/airflow/dbt_project && dbt "$$@"' --

.PHONY: dbt-run
dbt-run: ## Compile and run all dbt models inside the Airflow container
	@echo -e "${YELLOW}Running dbt transformations against PostgreSQL...${RESET}"
	@$(DBT_IN_AIRFLOW) run --profiles-dir . --target docker || \
		{ echo -e "${RED}adcreative_airflow is not running. Start it first with 'make up'.${RESET}"; exit 1; }
	@echo -e "${GREEN}✓ dbt models materialized successfully.${RESET}"

.PHONY: dbt-test
dbt-test: ## Run dbt data quality and integrity tests inside the Airflow container
	@echo -e "${YELLOW}Running dbt data quality tests...${RESET}"
	@$(DBT_IN_AIRFLOW) test --profiles-dir . --target docker || \
		{ echo -e "${RED}adcreative_airflow is not running. Start it first with 'make up'.${RESET}"; exit 1; }
	@echo -e "${GREEN}✓ dbt data tests passed.${RESET}"

.PHONY: dbt-docs
dbt-docs: ## Regenerate dbt docs/lineage (already served continuously at :8089 by 'make up')
	@echo -e "${YELLOW}Regenerating dbt documentation...${RESET}"
	@$(DBT_IN_AIRFLOW) docs generate --profiles-dir . --target docker || \
		{ echo -e "${RED}adcreative_airflow is not running. Start it first with 'make up'.${RESET}"; exit 1; }
	@echo -e "${GREEN}✓ dbt docs regenerated — view at http://localhost:8089${RESET}"

## -----------------------------------------------------------------------------
## Airflow Orchestration
## -----------------------------------------------------------------------------

.PHONY: airflow-trigger
airflow-trigger: ## Trigger the end-to-end Airflow DAG adcreative_end_to_end_pipeline
	@echo -e "${YELLOW}Triggering adcreative_end_to_end_pipeline DAG in Airflow...${RESET}"
	docker exec adcreative_airflow airflow dags unpause adcreative_end_to_end_pipeline || true
	docker exec adcreative_airflow airflow dags trigger adcreative_end_to_end_pipeline
	@echo -e "${GREEN}✓ DAG triggered. Monitor execution and task logs at http://localhost:8088${RESET}"

## -----------------------------------------------------------------------------
## Testing, Quality & Verification
## -----------------------------------------------------------------------------

.PHONY: test
test: $(VENV)/.installed ## Run unit and integration tests with pytest
	@echo -e "${YELLOW}Running test suite...${RESET}"
	$(PYTEST) tests/ -v --tb=short

.PHONY: api-health
api-health: ## Verify API container health via HTTP request
	@echo -e "${YELLOW}Querying http://localhost:8000/health...${RESET}"
	@curl -sf http://localhost:8000/health | python3 -m json.tool || echo -e "${RED}API is unreachable.${RESET}"

.PHONY: api-shell
api-shell: ## Open a bash shell inside the running API container
	docker exec -it adcreative_api /bin/bash

## -----------------------------------------------------------------------------
## Maintenance & Cleanup
## -----------------------------------------------------------------------------

.PHONY: clean
clean: ## Remove temporary Python caches, test caches, and notebook checkpoints
	@echo -e "${YELLOW}Cleaning Python bytecode and cache artifacts...${RESET}"
	@find . -type d \( -name "__pycache__" -o -name ".pytest_cache" -o -name ".ipynb_checkpoints" \) -not -path "./.venv/*" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -not -path "./.venv/*" -delete 2>/dev/null || true
	@echo -e "${GREEN}✓ Caches cleaned.${RESET}"

.PHONY: clean-venv
clean-venv: ## Remove the local virtual environment (.venv)
	@echo -e "${YELLOW}Removing virtual environment $(VENV)...${RESET}"
	@rm -rf $(VENV)
	@echo -e "${GREEN}✓ Virtual environment removed.${RESET}"

.PHONY: clean-all
clean-all: clean clean-venv ## Full teardown: containers, volumes, networks, caches, and venv
	@echo -e "${RED}Tearing down all project containers and volumes...${RESET}"
	$(DOCKER_COMPOSE) down -v --remove-orphans
	@echo -e "${GREEN}✓ Complete cleanup finished.${RESET}"
