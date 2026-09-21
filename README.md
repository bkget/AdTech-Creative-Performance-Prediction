# AdTech Creative Performance Prediction
[![CI Pipeline](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml/badge.svg)](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml)
[![Python 3.11](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Apache Airflow](https://img.shields.io/badge/Airflow-2.9.3-017CEE?style=flat&logo=apache-airflow&logoColor=white)](https://airflow.apache.org/)
[![dbt](https://img.shields.io/badge/dbt-1.8.2-FF694B?style=flat&logo=dbt&logoColor=white)](https://www.getdbt.com/)
[![PostgreSQL 17](https://img.shields.io/badge/PostgreSQL-17-4169E1?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![DVC](https://img.shields.io/badge/DVC-3.59-945DD6?style=flat&logo=dvc&logoColor=white)](https://dvc.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is an end-to-end Machine Learning and Data Engineering platform built to predict the performance of digital advertising creatives *before* they are launched. 

It transforms raw campaign logs, tabular metadata, and actual image pixels (using deep learning) through a **dbt** transformation tier, orchestrates the workflow via a standalone **Apache Airflow** DAG, serves predictions via a **FastAPI** backend, and visualizes insights on a dynamic, interactive dashboard.

---

## ⚡ Quick Access & Service Endpoints

When the stack is running via `make up` or `docker compose up -d`:

| Service | URL / Host | Credentials / Notes | Description |
|---|---|---|---|
| **Airflow Orchestrator** | [http://localhost:8088](http://localhost:8088) | `admin` / `admin` | Standalone Airflow DAG graph & pipeline run logs |
| **Interactive Dashboard** | [http://localhost:8000](http://localhost:8000) | None | Live Creative Performance Simulator & KPI analytics |
| **Interactive API Docs** | [http://localhost:8000/docs](http://localhost:8000/docs) | None | Swagger UI for `/api/predict`, `/api/stats`, `/api/benchmarks` |
| **Health Check** | [http://localhost:8000/health](http://localhost:8000/health) | None | Container health check and database status |
| **PostgreSQL Database** | `localhost:5432` | `adtech_user` / `adtech_password` (DB: `adcreative_db`) | 2-Tier Warehouse (`staging` + `analytics` schemas) |

---

## Table of Contents
1. [The Basics: Understanding Ad Analysis](#1-the-basics-understanding-ad-analysis)
2. [Overall Architecture Flow](#2-overall-architecture-flow)
3. [Key Technical Decisions & Framework Choices](#3-key-technical-decisions--framework-choices)
4. [Project Automation & Execution (Makefile & Docker)](#4-project-automation--execution-makefile--docker)
5. [Orchestration & Data Modeling (Airflow & dbt)](#5-orchestration--data-modeling-airflow--dbt)
6. [Database Connection & Schema Reference](#6-database-connection--schema-reference)
7. [How to Interact with the Project](#7-how-to-interact-with-the-project)
8. [Data Version Control (DVC) & Pipeline Lineage](#8-data-version-control-dvc--pipeline-lineage)

---

## 1. The Basics: Understanding Ad Analysis

### The Problem
When a brand (like Lexus or IHOP) runs a digital ad campaign, they spend thousands of dollars showing image ads to users on phones and computers. They want to know: **Which image will get the most clicks and engagement?** Normally, they have to spend money to test the ads live (A/B testing). 

### The Solution
We use Machine Learning to look at historical data and predict the future. We want our AI to say: *"Based on the budget, the target country, and the fact that this image is highly colorful and has a video component, we predict an Engagement Rate of 14%."*

### Key Concepts
*   **Impression:** One instance of an ad appearing on a user's screen.
*   **Engagement / Click:** When the user interacts with or clicks the ad.
*   **Engagement Rate (ER) & Click-Through Rate (CTR):** The metrics we are trying to predict (e.g., 100 impressions and 5 clicks = 5% CTR).
*   **Contextual Features:** The environment of the ad (e.g., User is on an iPhone, in the USA, and the campaign budget is $10k).
*   **Visual Features:** The actual pixels of the ad (e.g., Is the image bright? Is it colorful? What objects are in the image?).

Our approach is **Multimodal**, meaning we combine *Contextual* (text/numbers) and *Visual* (images) data together to make a much smarter prediction than using just one type of data.

---

## 2. Overall Architecture Flow

The system is built as a modern, decoupled 5-tier architecture:

```mermaid
flowchart TD
    %% =========================================================================
    %% Modern High-Contrast Theme Styling
    %% =========================================================================
    classDef rawCard fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef pipeCard fill:#1e1b4b,stroke:#a855f7,stroke-width:2px,color:#f8fafc;
    classDef dbCard fill:#022c22,stroke:#10b981,stroke-width:2px,color:#f8fafc;
    classDef dbtCard fill:#451a03,stroke:#f97316,stroke-width:2px,color:#f8fafc;
    classDef apiCard fill:#451a03,stroke:#f59e0b,stroke-width:2px,color:#f8fafc;
    classDef uiCard fill:#3b0764,stroke:#ec4899,stroke-width:2px,color:#f8fafc;

    subgraph RAW["📂 1. Multimodal Raw Ingestion"]
        A1["📋 briefing.csv<br/>Campaign budgets & dates"]
        A2["📊 campaigns_inventory.csv<br/>350k+ raw ad events"]
        A3["🖼️ Creative Assets_<br/>144 PNG ad images"]
        A4["🗂️ global_design_data.json<br/>Colors, labels & text"]
    end

    subgraph ORCH["✈️ 2. Airflow Orchestrator & ML (Port 8088)"]
        B1["🔗 Entity Resolution & Linking<br/>Slugs, Request IDs & MD5 Keys"]
        B2["👁️ Deep Vision Feature Extraction<br/>ResNet50 + PCA + Color Heuristics"]
        B3["🧠 Multimodal Feature Engineering<br/>Campaign-Grouped 5-Fold Cross-Validation"]
        B4["🏆 LightGBM Model Serialization<br/>ER & CTR Predictors (models/*.pkl)"]
    end

    subgraph STAGING["🗄️ 3. PostgreSQL Raw Warehouse (staging schema)"]
        C1[("📦 staging.raw_briefing")]
        C2[("📦 staging.raw_inventory")]
        C3[("📦 staging.raw_vision_features")]
        C4[("📦 staging.raw_creative_assets")]
    end

    subgraph DBT["🏗️ 4. dbt Transformation Layer (dbt-postgres)"]
        D1["📊 analytics.dim_campaigns"]
        D2["🎨 analytics.dim_creatives"]
        D3["📈 analytics.fact_creative_performance"]
        D4["👁️ analytics.v_campaign_benchmarks"]
    end

    subgraph SERVING["🚀 5. Inference & Serving API (FastAPI - Port 8000)"]
        E1["⚡ FastAPI REST Backend<br/>/api/stats · /api/benchmarks · /api/predict"]
    end

    subgraph DASH["📱 6. Interactive Client Dashboard (app/index.html)"]
        F1["🎯 AdCreative Intelligence Dashboard<br/>Live KPI Cards · Model R² Charts · Simulator"]
    end

    A1 & A2 & A3 & A4 --> B1
    B1 --> B2 --> B3 --> B4
    B3 -->|"Extract & Load"| STAGING
    STAGING -->|"dbt run & dbt test"| DBT
    DBT -->|"SQLAlchemy ORM"| E1
    E1 -->|"REST JSON Streams"| F1

    class A1,A2,A3,A4 rawCard;
    class B1,B2,B3,B4 pipeCard;
    class C1,C2,C3,C4 dbCard;
    class D1,D2,D3,D4 dbtCard;
    class E1 apiCard;
    class F1 uiCard;
```

---

## 3. Key Technical Decisions & Framework Choices

### A. Machine Learning Model: LightGBM vs. XGBoost / Random Forest
*   **Decision:** LightGBM.
*   **Why?** Tree-based models dominate tabular data. LightGBM handles categorical variables (like `device_type` or `geo_country`) natively without needing massive One-Hot Encoding arrays. It is significantly faster to train than XGBoost and handles missing data gracefully. 
*   **Evaluation:** We used **GroupKFold** cross-validation grouped by `campaign_id`. This is critical: standard splitting would leak data (the model would memorize campaigns). GroupKFold forces the model to predict on *entirely unseen campaigns*, proving it actually learned generalizable patterns.

### B. Computer Vision: ResNet50 vs. CLIP vs. Basic OpenCV
*   **Decision:** ResNet50 (Deep Learning) + OpenCV heuristics.
*   **Why?** While OpenAI's CLIP is the state-of-the-art for image-text matching, it is heavy and requires a GPU. ResNet50 is lightweight enough to run on a standard CPU laptop. We pass the ad images through ResNet50 to get a 2048-dimension vector, then use **PCA (Principal Component Analysis)** to compress it down to 32 dimensions so the LightGBM model isn't overwhelmed. We also combined this with standard heuristics (Brightness, Saturation, Entropy) which are highly interpretable for clients.

### C. Data Transformations: dbt vs. Raw Python Loops
*   **Decision:** dbt Core (`dbt-postgres`).
*   **Why?** Decoupling extraction/loading from business transformation ensures SQL transformations are compiled, tested, version-controlled, and run directly inside the PostgreSQL database engine.

### D. Pipeline Orchestration: Standalone Airflow vs. Cron
*   **Decision:** Ultra-lightweight standalone Apache Airflow (`SequentialExecutor` + SQLite on port `8088`).
*   **Why?** Provides full visual DAG inspection, task retry logic, and monitoring UI without the multi-gigabyte memory footprint of distributed Airflow.

### E. Model Serving & Deployment Architecture: Local Container Fleet vs. Cloud
*   **Decision:** Containerized FastAPI Microservice (`Dockerfile.api`) orchestrated alongside PostgreSQL and Airflow via Docker Compose.
*   **Why?** Fully decoupled, reproducible, and zero cloud hosting costs for review. Provides full OpenAPI documentation (`/docs`), automated container healthchecks (`/health`), and serves the interactive dashboard frontend.
*   **AdTech Production Reality (Latency vs. Accuracy):** In programmatic real-time bidding (RTB), auction decisions must be returned in **< 15ms**. Running deep vision extraction (ResNet50) synchronously during bid evaluation is impossible. This project implements the industry-standard two-tier pattern:
    1. **Pre-Campaign / Creative Studio (Online REST API):** Marketers upload creative assets to test predicted ER/CTR via FastAPI before allocating media budgets.
    2. **Live Auction Bidding (Batch Pre-Scoring):** The Airflow DAG pre-extracts vision features and scores creatives into the analytical warehouse/feature store, enabling sub-millisecond key-value lookups during live RTB auctions.
*   **Cloud Production Readiness:** The container is 100% cloud-ready and can be deployed directly to **AWS ECS (Fargate)**, **GCP Cloud Run**, or **Kubernetes** with zero code changes.

---

## 4. Project Automation & Execution (Makefile & Docker)

The project includes an intelligent, colorized **Makefile** that automates the entire lifecycle: container orchestration, Airflow triggers, dbt model materialization, testing, and cleanup.

### A. Quick Start with Make (Recommended)

```bash
# 1. One-command setup & container start
make setup && make up
```

Type `make` or `make help` to inspect all available targets:

```
AdTech Creative Performance Prediction — Automation CLI

Usage: make <target>

  help                 Display this help menu
  venv                 Create the virtual environment and install dependencies
  setup                Initialize .env and install local dependencies (first-time setup)
  init-env             Create .env from .env.example if not already present
  install              Install/update Python dependencies into the virtual environment
  up                   Start all containers in detached mode (builds only if missing)
  build                Build or rebuild Docker images without starting containers
  up-build             Force rebuild images, then start containers in detached mode
  down                 Stop and remove all containers, networks, and ephemeral state
  stop                 Alias for 'make down'
  restart              Restart the full container stack
  logs                 Tail streaming logs from all running containers
  logs-api             Tail logs from the API service
  logs-db              Tail logs from the PostgreSQL database
  logs-airflow         Tail logs from the Airflow orchestrator
  db-shell             Open an interactive psql shell inside the running Postgres container
  db-reset             Hard reset the database volume and recreate it (wipes all data)
  dvc-repro            Reproduce the DVC pipeline: vision → features → benchmark → train
  dvc-metrics          Display model evaluation metrics tracked by DVC
  dvc-status           Check DVC pipeline stage status and data cache
  run-pipeline         Run the ML pipeline directly with the local venv (bypasses DVC caching)
  run-pipeline-docker  Run the ML pipeline in a one-off container (no local Python/venv needed)
  dbt-run              Compile and run all dbt models inside the Airflow container
  dbt-test             Run dbt data quality and integrity tests inside the Airflow container
  dbt-docs             Regenerate dbt docs/lineage (already served continuously at :8089 by 'make up')
  airflow-trigger      Trigger the end-to-end Airflow DAG adcreative_end_to_end_pipeline
  test                 Run unit and integration tests with pytest
  api-health           Verify API container health via HTTP request
  api-shell            Open a bash shell inside the running API container
  clean                Remove temporary Python caches, test caches, and notebook checkpoints
  clean-venv           Remove the local virtual environment (.venv)
  clean-all            Full teardown: containers, volumes, networks, caches, and venv

Quick Start: make setup && make up   (then make dvc-repro once, to populate data/models)
```

> **Note:** `dvc-repro` / `run-pipeline` and `dbt-run` / `dbt-test` are manual, local dev conveniences.
> Once containers are up, the Airflow DAG (`adcreative_end_to_end_pipeline`) already runs the full
> ELT + dbt + serving-verification lifecycle end-to-end on its own — see section 5 below.

---

### B. Command Reference by Workflow

#### 1. ML Pipeline (local, via DVC)
```bash
# Reproduce the pipeline (vision → features → benchmark → train), with caching:
make dvc-repro

# Or run it directly without DVC's cache/skip logic:
make run-pipeline

# Or run it in a one-off container instead of a local venv:
make run-pipeline-docker
```

#### 2. dbt Data Modeling & Testing
```bash
# Materialize all staging views and analytics tables:
make dbt-run

# Run data quality integrity tests:
make dbt-test

# Regenerate interactive dbt documentation (served continuously at :8089):
make dbt-docs
```

#### 3. Airflow Orchestration
```bash
# Trigger the complete end-to-end pipeline in Airflow:
make airflow-trigger

# Stream Airflow logs:
make logs-airflow
```

---

## 5. Orchestration & Data Modeling (Airflow & dbt)

### A. Airflow DAG Workflow (`adcreative_end_to_end_pipeline`)

Open **[http://localhost:8088](http://localhost:8088)** (`admin`/`admin`) to inspect the execution graph:

```
[entity_resolution_and_linking]
               ↓
[extract_deep_vision_features] (ResNet50 + PCA-32)
               ↓
[engineer_multimodal_features]
               ↓
[train_and_evaluate_models] (LightGBM CV)
               ↓
[load_raw_staging_warehouse] (PostgreSQL Staging)
               ↓
[dbt_run_transformations] (dbt run → analytics.*)
               ↓
[dbt_test_data_quality] (dbt test)
               ↓
[verify_api_and_dashboard] (FastAPI Healthcheck)
```

---

The Airflow DAG and dbt project are organized under [`orchestration/`](file:///home/biruk-getaneh/projects/personal/AdTech-Creative-Performance-Prediction/orchestration/):

```
orchestration/
├── airflow_dag/
│   └── adcreative_pipeline_dag.py
└── dbt_project/
    ├── dbt_project.yml
    ├── profiles.yml
    ├── macros/
    │   └── generate_schema_name.sql
    └── models/
        ├── staging/
        │   ├── schema.yml
        │   ├── stg_briefing.sql
        │   ├── stg_inventory.sql
        │   ├── stg_vision_features.sql
        │   └── stg_creative_assets.sql
        └── marts/
            ├── schema.yml
            ├── dim_campaigns.sql
            ├── dim_creatives.sql
            ├── fact_creative_performance.sql
            └── v_campaign_benchmarks.sql
```

---

## 6. Database Connection & Schema Reference

When running with Docker, PostgreSQL is exposed on port `5432` with the database `adcreative_db`.

### A. Connection Credentials

| Parameter | Value (Host Access) | Value (Docker Network) |
| :--- | :--- | :--- |
| **Host** | `localhost` or `127.0.0.1` | `adcreative_db` |
| **Port** | `5432` | `5432` |
| **Database** | `adcreative_db` | `adcreative_db` |
| **Username** | `adtech_user` | `adtech_user` |
| **Password** | `adtech_password` | `adtech_password` |
| **Connection URI** | `postgresql://adtech_user:adtech_password@localhost:5432/adcreative_db` | `postgresql://adtech_user:adtech_password@adcreative_db:5432/adcreative_db` |

#### One-Command Terminal Access:
```bash
make db-shell
```

---

### B. Sample SQL Queries for Inspection

```sql
-- 1. Top 5 Best Performing Creatives by Engagement Rate
SELECT 
    c.creative_id,
    c.campaign_name,
    f.impressions,
    f.engagements,
    ROUND((f.engagement_rate * 100)::numeric, 2) AS er_percent,
    ROUND((f.click_through_rate * 100)::numeric, 2) AS ctr_percent
FROM analytics.fact_creative_performance f
JOIN analytics.dim_campaigns c ON f.campaign_id = c.campaign_id
WHERE f.impressions >= 1000
ORDER BY f.engagement_rate DESC
LIMIT 5;

-- 2. Campaign Benchmarks from dbt Analytical View
SELECT 
    campaign_name,
    num_creatives,
    total_impressions,
    avg_engagement_rate_pct,
    avg_click_through_rate_pct
FROM analytics.v_campaign_benchmarks
ORDER BY total_impressions DESC
LIMIT 10;
```

---

## 7. How to Interact with the Project

### A. The Web Dashboard
Navigate to **[http://localhost:8000](http://localhost:8000)** in your browser:
*   **Creative Performance Simulator:** Sliders allow you to adjust budget, target geo, device type, and visual features (brightness, color saturation) to receive instant predicted ER and CTR scores with uncertainty intervals.
*   **Benchmark Explorer:** Compare predicted ad performance against historical 25th, 50th, and 75th percentile benchmarks.
*   **Model Accuracy & Feature Importance:** Live charts showing LightGBM cross-validation scores ($R^2$, RMSE) and top predictive visual vs. contextual features.

### B. Interactive API Documentation
Open **[http://localhost:8000/docs](http://localhost:8000/docs)** to test the REST endpoints:
*   `GET /health`: Health check and system readiness verification.
*   `GET /api/stats`: Aggregate platform metrics (total campaigns, impressions, creatives).
*   `GET /api/benchmarks`: Metric percentiles grouped by advertiser and country.
*   `POST /api/predict`: Returns real-time multimodal model predictions for any campaign payload.

---

## 8. Data Version Control (DVC) & Pipeline Lineage

This project implements industry-standard **Data Version Control (DVC)** for data artifact tracking, pipeline stage caching, and experiment reproducibility.

```bash
# 1. Reproduce entire pipeline with Make (or dvc repro)
make dvc-repro

# 2. View model evaluation metrics across commits
make dvc-metrics

# 3. View pipeline status and cached stages
make dvc-status
```

### Restoring / Pulling Data on a New Machine

The datasets under `data/` are not stored in git — only small `.dvc` pointer files are tracked. The actual data lives in a Google Drive remote (`gdrive_storage`) and is fetched on demand with DVC.

```bash
git clone <repo-url>
cd AdTech-Creative-Performance-Prediction
make setup          # creates .venv and installs dependencies, including dvc[gdrive]
.venv/bin/dvc pull  # downloads the data referenced by the .dvc files into data/
```

The first `dvc pull` (or `dvc push`) on a new machine opens a browser window asking you to sign in with the Google account that has access to the shared Drive folder and approve access. This is a one-time step — the resulting token is cached locally under `~/.cache/pydrive2fs/`, so later `dvc pull` / `dvc push` calls won't prompt again.

> **Note:** If Google shows *"This app is blocked"* during that first sign-in, it means DVC's shared default OAuth client has been rate-limited by Google across all of its users — not an error in this project. Fix it by registering your own free OAuth client in [Google Cloud Console](https://console.cloud.google.com/) (APIs & Services → Credentials → **Create OAuth client ID** → Desktop app), then point DVC at it locally:
> ```bash
> dvc remote modify --local gdrive_storage gdrive_client_id '<your-client-id>'
> dvc remote modify --local gdrive_storage gdrive_client_secret '<your-client-secret>'
> ```
> These are written to `.dvc/config.local`, which is git-ignored and never committed.
