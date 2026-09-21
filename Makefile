# ==============================================================================
# AdTech Creative Performance Prediction - Intelligent Makefile
# ==============================================================================
# Includes automation for Container Orchestration, Database Administration,
# DVC Experiment Pipelines, Code Quality & Development Lifecycle.
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Environment configuration
ENV_FILE ?= .env
ifeq ($(wildcard $(ENV_FILE)),)
    $(shell cp .env.example .env 2>/dev/null || true)
endif

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
## 📌 Help & Discovery
## -----------------------------------------------------------------------------

.PHONY: help
help: ## Display this interactive help menu
	@echo -e "\n${BOLD}${BLUE}AdTech Creative Performance Prediction — Automation CLI${RESET}\n"
	@echo -e "${YELLOW}Usage:${RESET} make ${GREEN}<target>${RESET}\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-20s${RESET} %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo -e "\n${BOLD}Quick Start:${RESET} ${GREEN}make setup && make up${RESET}\n"

## -----------------------------------------------------------------------------
## 🚀 Environment & Setup
## -----------------------------------------------------------------------------

.PHONY: setup
setup: init-env install ## Initialize environment file and install local dependencies

.PHONY: init-env
init-env: ## Create .env from .env.example if not already present
	@if [ ! -f .env ]; then \
		echo -e "${YELLOW}Creating .env from .env.example...${RESET}"; \
		cp .env.example .env; \
		echo -e "${GREEN}✓ .env file created.${RESET}"; \
	else \
		echo -e "${BLUE}ℹ .env already exists.${RESET}"; \
	fi

.PHONY: install
install: ## Install Python dependencies into active virtual environment
	@echo -e "${YELLOW}Installing project dependencies...${RESET}"
	pip install --upgrade pip
	pip install -r requirements.txt
	@echo -e "${GREEN}✓ Dependencies installed successfully.${RESET}"

## -----------------------------------------------------------------------------
## 🐳 Docker & Container Lifecycle
## -----------------------------------------------------------------------------

.PHONY: up
up: init-env ## Build and start all containers in detached mode
	@echo -e "${YELLOW}Starting container fleet (adcreative_db, adcreative_api)...${RESET}"
	$(DOCKER_COMPOSE) up -d --build
	@echo -e "${GREEN}✓ Containers launched.${RESET}"
	@echo -e "${BLUE}  • Web API:${RESET}     http://localhost:8000/docs"
	@echo -e "${BLUE}  • Health Check:${RESET} http://localhost:8000/health"
	@echo -e "${BLUE}  • Database:${RESET}     localhost:5432 (adcreative_db)"

.PHONY: down
down: ## Stop and remove all containers, networks, and ephemeral state
	@echo -e "${YELLOW}Stopping containers...${RESET}"
	$(DOCKER_COMPOSE) down
	@echo -e "${GREEN}✓ Containers stopped.${RESET}"

.PHONY: restart
restart: down up ## Restart the full container stack

.PHONY: ps status
ps status: ## List running containers and health statuses
	$(DOCKER_COMPOSE) ps

.PHONY: logs
logs: ## Tail streaming logs from all running containers
	$(DOCKER_COMPOSE) logs -f

.PHONY: logs-api
logs-api: ## Tail logs specifically from the API service
	$(DOCKER_COMPOSE) logs -f adcreative_api

.PHONY: logs-db
logs-db: ## Tail logs specifically from the PostgreSQL database
	$(DOCKER_COMPOSE) logs -f adcreative_db

## -----------------------------------------------------------------------------
## 🗄️ Database Administration
## -----------------------------------------------------------------------------

.PHONY: db-shell
db-shell: ## Open an interactive psql shell inside adcreative_db
	@echo -e "${YELLOW}Connecting to adcreative_db via psql...${RESET}"
	docker exec -it adcreative_db psql -U $$(grep DB_USER .env | cut -d '=' -f2 || echo "adtech_user") -d $$(grep DB_NAME .env | cut -d '=' -f2 || echo "adtech_db")

.PHONY: db-init
db-init: ## Execute database schema initialization script
	@echo -e "${YELLOW}Running DB initialization script...${RESET}"
	python scripts/init_db.py
	@echo -e "${GREEN}✓ Database initialized.${RESET}"

.PHONY: db-reset
db-reset: ## Hard reset database volume and recreate schemas (Caution: wipes data)
	@echo -e "${RED}Resetting PostgreSQL volume and restarting adcreative_db...${RESET}"
	$(DOCKER_COMPOSE) down -v
	$(DOCKER_COMPOSE) up -d adcreative_db
	@echo -e "${GREEN}✓ Clean database restarted.${RESET}"

## -----------------------------------------------------------------------------
## 🧠 ML Pipeline & DVC Workflow
## -----------------------------------------------------------------------------

.PHONY: dvc-repro
dvc-repro: ## Reproduce entire DVC pipeline from raw assets to evaluation
	@echo -e "${YELLOW}Executing DVC pipeline (extract -> prepare -> train -> evaluate)...${RESET}"
	dvc repro
	@echo -e "${GREEN}✓ DVC pipeline reproduction complete.${RESET}"

.PHONY: dvc-metrics
dvc-metrics: ## Display model evaluation metrics tracked by DVC
	@echo -e "${YELLOW}DVC Evaluation Metrics:${RESET}"
	dvc metrics show

.PHONY: dvc-status
dvc-status: ## Check DVC pipeline stage status and data cache
	dvc status

.PHONY: run-pipeline
run-pipeline: ## Run the full end-to-end Python ML pipeline directly
	@echo -e "${YELLOW}Running complete ML pipeline...${RESET}"
	python -m src.pipeline.run_pipeline
	@echo -e "${GREEN}✓ ML pipeline executed successfully.${RESET}"

## -----------------------------------------------------------------------------
## 🧪 Testing, Quality & Verification
## -----------------------------------------------------------------------------

.PHONY: test
test: ## Run unit and integration tests with pytest
	@echo -e "${YELLOW}Running test suite...${RESET}"
	pytest tests/ -v --tb=short

.PHONY: api-health
api-health: ## Verify API container health via HTTP request
	@echo -e "${YELLOW}Querying http://localhost:8000/health...${RESET}"
	@curl -sf http://localhost:8000/health | python -m json.tool || echo -e "${RED}API is unreachable.${RESET}"

.PHONY: api-shell
api-shell: ## Open a bash shell inside the running API container
	docker exec -it adcreative_api /bin/bash

## -----------------------------------------------------------------------------
## 🧹 Maintenance & Cleanup
## -----------------------------------------------------------------------------

.PHONY: clean
clean: ## Remove temporary python caches, logs, and build artifacts
	@echo -e "${YELLOW}Cleaning python bytecode and test cache artifacts...${RESET}"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ipynb_checkpoints" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@echo -e "${GREEN}✓ Caches cleaned.${RESET}"

.PHONY: clean-all
clean-all: clean ## Complete teardown: remove containers, volumes, networks, and caches
	@echo -e "${RED}Teardown of all project containers and volumes...${RESET}"
	$(DOCKER_COMPOSE) down -v --remove-orphans
	@echo -e "${GREEN}✓ Complete cleanup finished.${RESET}"
