# AdTech Creative Performance Prediction
[![CI Pipeline](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml/badge.svg)](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml)
[![Python 3.11](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![PostgreSQL 17](https://img.shields.io/badge/PostgreSQL-17-4169E1?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![DVC](https://img.shields.io/badge/DVC-3.59-945DD6?style=flat&logo=dvc&logoColor=white)](https://dvc.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is an end-to-end Machine Learning and Data Engineering platform built to predict the performance of digital advertising creatives *before* they are launched. 

It transforms raw campaign logs, tabular metadata, and actual image pixels (using deep learning) into a unified PostgreSQL database, serves the insights via a FastAPI backend, and visualizes them on a dynamic, interactive dashboard.

---

## 📑 Table of Contents
1. [The Basics: Understanding Ad Analysis](#1-the-basics-understanding-ad-analysis)
2. [Overall Architecture Flow](#2-overall-architecture-flow)
3. [Key Technical Decisions & Framework Choices](#3-key-technical-decisions--framework-choices)
4. [🛠️ Project Automation & Execution (Makefile & Docker)](#4-project-automation--execution-makefile--docker)
5. [🗄️ Database Connection & Schema Reference](#5-database-connection--schema-reference)
6. [How to Interact with the Project](#6-how-to-interact-with-the-project)
7. [🔄 Data Version Control (DVC) & Pipeline Lineage](#7-data-version-control-dvc--pipeline-lineage)

---

## 1. The Basics: Understanding Ad Analysis

### The Problem
When a brand (like Lexus or IHOP) runs a digital ad campaign, they spend thousands of dollars showing image ads to users on phones and computers. They want to know: **Which image will get the most clicks and engagement?** Normally, they have to spend money to test the ads live (A/B testing). 

### The Solution
We use Machine Learning to look at historical data and predict the future. We want our AI to say: *"Based on the budget, the target country, and the fact that this image is highly colorful and has a video component, we predict an Engagement Rate of 14%."*

### Key Concepts
*   **Impression:** One instance of an ad appearing on a user's screen.
*   **Engagement / Click:** When the user interacts with or clicks the ad.
*   **Engagement Rate (ER) & Click-Through Rate (CTR):** The metrics we are trying to predict. (e.g., 100 impressions and 5 clicks = 5% CTR).
*   **Contextual Features:** The environment of the ad (e.g., User is on an iPhone, in the USA, and the campaign budget is $10k).
*   **Visual Features:** The actual pixels of the ad (e.g., Is the image bright? Is it colorful? What objects are in the image?).

Our approach is **Multimodal**, meaning we combine *Contextual* (text/numbers) and *Visual* (images) data together to make a much smarter prediction than using just one type of data.

---

## 2. Overall Architecture Flow

The system is built as a modern, decoupled 4-layer architecture:

```mermaid
flowchart TD
    %% =========================================================================
    %% Modern High-Contrast Theme Styling
    %% =========================================================================
    classDef rawCard fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef pipeCard fill:#1e1b4b,stroke:#a855f7,stroke-width:2px,color:#f8fafc;
    classDef dbCard fill:#022c22,stroke:#10b981,stroke-width:2px,color:#f8fafc;
    classDef apiCard fill:#451a03,stroke:#f59e0b,stroke-width:2px,color:#f8fafc;
    classDef uiCard fill:#3b0764,stroke:#ec4899,stroke-width:2px,color:#f8fafc;

    subgraph RAW["📂 1. Multimodal Raw Ingestion"]
        A1["📋 briefing.csv<br/>Campaign budgets & dates"]
        A2["📊 campaigns_inventory.csv<br/>350k+ raw ad events"]
        A3["🖼️ Creative Assets_<br/>144 PNG ad images"]
        A4["🗂️ global_design_data.json<br/>Colors, labels & text"]
    end

    subgraph PIPELINE["⚙️ 2. ML & Feature Pipeline (src/pipeline/run_all.py)"]
        B1["🔗 Entity Resolution & Linking<br/>Slugs, Request IDs & MD5 Keys"]
        B2["👁️ Deep Vision Feature Extraction<br/>ResNet50 + PCA + Color Heuristics"]
        B3["🧠 Feature Engineering & LightGBM<br/>Campaign-Grouped 5-Fold Cross-Validation"]
    end

    subgraph STORE["🗄️ 3. PostgreSQL Data Warehouse (adcreative_db)"]
        C1[("📦 staging schema<br/>5 Raw Audit Tables")]
        C2[("📊 analytics schema<br/>Curated Dimensions & Facts")]
    end

    subgraph SERVING["🚀 4. Inference & Serving API (FastAPI)"]
        D1["⚡ FastAPI REST Backend<br/>/api/stats · /api/benchmarks · /api/predict"]
    end

    subgraph DASH["📱 5. Interactive Client Dashboard (app/index.html)"]
        E1["🎯 AdCreative Intelligence Dashboard<br/>Live KPI Cards · Model R² Charts · Simulator"]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1
    A4 --> B1
    B1 --> B2
    B2 --> B3
    B3 -->|"Parquet & JSON Cache"| C1
    C1 -->|"SQL Transforms & Joins"| C2
    C2 -->|"SQLAlchemy ORM - Port 5432"| D1
    D1 -->|"REST JSON - Port 8000"| E1

    class A1,A2,A3,A4 rawCard;
    class B1,B2,B3 pipeCard;
    class C1,C2 dbCard;
    class D1 apiCard;
    class E1 uiCard;
```

### The Flow:
1.  **Pipeline (`src/pipeline/run_all.py`):** Resolves messy entity links, extracts ResNet50 vision features, engineers all features, and trains LightGBM — saving results to `.parquet` and `.json` caches.
2.  **Database Loader (`src/db/load.py`):** Reads those caches and loads them cleanly into a relational PostgreSQL database.
3.  **Backend API (`src/api/main.py`):** Connects to the database and exposes `/api/stats`, `/api/benchmarks`, and `/api/predict` endpoints.
4.  **Frontend Dashboard (`app/index.html`):** Fetches live data from the API and renders an interactive Creative Performance Simulator.

---

## 3. Key Technical Decisions & Framework Choices

Why did we choose these specific tools from the vast sea of available options?

### A. Machine Learning Model: LightGBM vs. XGBoost / Random Forest
*   **Decision:** LightGBM.
*   **Why?** Tree-based models dominate tabular data. LightGBM handles categorical variables (like `device_type` or `geo_country`) natively without needing massive One-Hot Encoding arrays. It is significantly faster to train than XGBoost and handles missing data gracefully. 
*   **Evaluation:** We used **GroupKFold** cross-validation grouped by `campaign_id`. This is critical: standard splitting would leak data (the model would memorize campaigns). GroupKFold forces the model to predict on *entirely unseen campaigns*, proving it actually learned generalizable patterns.

### B. Computer Vision: ResNet50 vs. CLIP vs. Basic OpenCV
*   **Decision:** ResNet50 (Deep Learning) + OpenCV heuristics.
*   **Why?** While OpenAI's CLIP is the state-of-the-art for image-text matching, it is heavy and requires a GPU. ResNet50 is lightweight enough to run on a standard CPU laptop. We pass the ad images through ResNet50 to get a 2048-dimension vector, then use **PCA (Principal Component Analysis)** to compress it down to 32 dimensions so the LightGBM model isn't overwhelmed. We also combined this with standard heuristics (Brightness, Saturation, Entropy) which are highly interpretable for clients.

### C. Backend API: FastAPI vs. Flask / Django
*   **Decision:** FastAPI.
*   **Why?** Django is too heavy for a simple data-serving layer. Flask is classic but synchronous by default. FastAPI provides automatic data validation (via Pydantic), is extremely fast, and requires minimal boilerplate to spin up a robust JSON API.

### D. Database: PostgreSQL vs. MongoDB / SQLite
*   **Decision:** PostgreSQL.
*   **Why?** Advertising data is highly relational (Campaigns -> Creatives -> Impressions). While MongoDB handles unstructured JSON well, predicting metrics requires strict schema enforcement and aggregations, which SQL does perfectly. SQLite is great for prototypes, but PostgreSQL proves production readiness and integrates perfectly with Docker.

---

## 4. 🛠️ Project Automation & Execution (Makefile & Docker)

The project includes an intelligent, colorized **Makefile** that automates the entire lifecycle: container orchestration, database administration, DVC reproduction, testing, and cleanup.

### A. Quick Start with Make (Recommended)

```bash
# 1. One-command setup & container start
make setup && make up
```

Type `make` or `make help` to inspect all available targets:

```
AdTech Creative Performance Prediction — Automation CLI

Usage: make <target>

  help                 Display this interactive help menu
  setup                Initialize environment file and install local dependencies
  init-env             Create .env from .env.example if not already present
  install              Install Python dependencies into active virtual environment
  up                   Build and start all containers in detached mode
  down                 Stop and remove all containers, networks, and ephemeral state
  restart              Restart the full container stack
  logs                 Tail streaming logs from all running containers
  logs-api             Tail logs specifically from the API service
  logs-db              Tail logs specifically from the PostgreSQL database
  db-shell             Open an interactive psql shell inside adcreative_db
  db-init              Execute database schema initialization script
  db-reset             Hard reset database volume and recreate schemas (Caution: wipes data)
  dvc-repro            Reproduce entire DVC pipeline from raw assets to evaluation
  dvc-metrics          Display model evaluation metrics tracked by DVC
  dvc-status           Check DVC pipeline stage status and data cache
  run-pipeline         Run the full end-to-end Python ML pipeline directly
  test                 Run unit and integration tests with pytest
  api-health           Verify API container health via HTTP request
  api-shell            Open a bash shell inside the running API container
  clean                Remove temporary python caches, logs, and build artifacts
  clean-all            Complete teardown: remove containers, volumes, networks, and caches
```

---

### B. Command Reference by Workflow

#### 1. Container Lifecycle
| Command | Action |
|---|---|
| `make up` | Builds images and starts `adcreative_db` and `adcreative_api` in detached mode |
| `make down` | Gracefully stops and tears down the container fleet |
| `make restart` | Restarts all containers |
| `make logs` | Streams consolidated logs across all containers |
| `make logs-api` | Streams logs specifically from FastAPI backend |
| `make logs-db` | Streams PostgreSQL database logs |
| `make ps` | Displays container status and health checks |

#### 2. Database Administration
| Command | Action |
|---|---|
| `make db-shell` | Directly opens interactive `psql` shell inside `adcreative_db` |
| `make db-init` | Executes schema initialization script (`scripts/init_db.py`) |
| `make db-reset` | Wipes volume and restarts a pristine database instance |

#### 3. ML Pipeline & DVC Experiment Tracking
| Command | Action |
|---|---|
| `make dvc-repro` | Executes DVC pipeline DAG (extract $\to$ prepare $\to$ train $\to$ evaluate) |
| `make dvc-metrics`| Shows model performance metrics from tracked experiments |
| `make dvc-status` | Inspects data cache and modified stage states |
| `make run-pipeline` | Runs the full Python pipeline directly |

#### 4. Testing, Health & Maintenance
| Command | Action |
|---|---|
| `make test` | Executes unit and integration test suite via `pytest` |
| `make api-health` | Curls `http://localhost:8000/health` and verifies status |
| `make api-shell` | Enters a bash terminal inside the running API container |
| `make clean` | Removes bytecode caches (`__pycache__`, `.pytest_cache`, `.ipynb_checkpoints`) |
| `make clean-all` | Deep clean removing containers, volumes, and caches |

---

### C. Standard Docker Compose (Without Make)

If `make` is not available on your system, you can run native Docker Compose commands:

```bash
# Setup environment file
cp .env.example .env

# Start containers
docker compose up -d --build

# View logs
docker compose logs -f

# Stop containers
docker compose down
```

---

### D. Running Locally (Native Python)

If you prefer developing directly on your host machine:

**Prerequisites:** Python 3.11+ and PostgreSQL running on `localhost:5432` with credentials `adtech_user/adtech_password`.

```bash
# 1. Install dependencies
make install

# 2. Run the ML Pipeline
make run-pipeline

# 3. Initialize DB and load data
make db-init
python -m src.db.load

# 4. Start the API & Dashboard server
python -m uvicorn src.api.main:app --port 8000
```
Open **[http://localhost:8000](http://localhost:8000)** in your browser.

---

## 5. 🗄️ Database Connection & Schema Reference

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

---

### B. How to Connect

#### Option 1: One-Command Make Target (Recommended)
```bash
make db-shell
```

#### Option 2: Docker Exec Direct Access
```bash
docker exec -it adcreative_db psql -U adtech_user -d adcreative_db
```

#### Option 3: Connect via Host `psql` / GUI Client (DBeaver, TablePlus, DataGrip)
```bash
psql -h localhost -p 5432 -U adtech_user -d adcreative_db
```

---

### C. Database Architecture: 2-Tier Schema Design

The database employs a clean 2-tier architecture separating raw ingested staging data from curated business analytics:

```mermaid
erDiagram
    %% =========================================================================
    %% Schema ER Diagram
    %% =========================================================================
    
    %% Staging Schema
    "staging.stg_briefing" {
        string campaign_id PK
        string campaign_name
        string advertiser
        float budget_usd
        date start_date
        date end_date
    }

    "staging.stg_inventory" {
        string event_id PK
        string campaign_id FK
        string creative_id FK
        string device_os
        string geo_country
        boolean engaged
        boolean clicked
    }

    "staging.stg_image_features" {
        string creative_id PK
        float brightness
        float saturation
        float entropy
        string[] detected_labels
        float[] resnet50_pca32
    }

    %% Analytics Schema
    "analytics.dim_campaigns" {
        string campaign_id PK
        string campaign_name
        string advertiser
        float budget_usd
        int total_creatives
    }

    "analytics.dim_creatives" {
        string creative_id PK
        string visual_complexity
        float dominant_saturation
        string color_palette
    }

    "analytics.fact_creative_performance" {
        string fact_id PK
        string campaign_id FK
        string creative_id FK
        int impressions
        int engagements
        int clicks
        float engagement_rate
        float click_through_rate
    }

    "staging.stg_briefing" ||--o{ "analytics.dim_campaigns" : "transforms to"
    "staging.stg_image_features" ||--o{ "analytics.dim_creatives" : "curated to"
    "staging.stg_inventory" ||--o{ "analytics.fact_creative_performance" : "aggregates to"
    "analytics.dim_campaigns" ||--o{ "analytics.fact_creative_performance" : "belongs to"
    "analytics.dim_creatives" ||--o{ "analytics.fact_creative_performance" : "measures"
```

---

### D. Table & View Dictionary

#### 1. `staging` Schema (Raw Audit Layer)
| Table | Description | Primary Key |
| :--- | :--- | :--- |
| `staging.stg_briefing` | Raw campaign briefs, budgets, and objectives | `campaign_id` |
| `staging.stg_inventory` | 350,000+ raw ad event logs (impressions, clicks, engagements) | `event_id` |
| `staging.stg_image_features` | Extracted deep vision vectors (ResNet50 + PCA) & color heuristics | `creative_id` |
| `staging.stg_global_design` | Extracted UI text, dominant colors, and bounding boxes | `creative_id` |

#### 2. `analytics` Schema (Curated Data Mart)
| Table / View | Description | Key Metrics |
| :--- | :--- | :--- |
| `analytics.dim_campaigns` | Clean campaign dimension | `budget_usd`, `duration_days` |
| `analytics.dim_creatives` | Creative metadata & visual feature attributes | `brightness`, `entropy`, `complexity` |
| `analytics.fact_creative_performance` | Aggregated performance fact table | `impressions`, `engagements`, `er`, `ctr` |
| `analytics.v_campaign_benchmarks` | Analytical view computing 25th, 50th, 75th percentile benchmarks | `p25_er`, `median_er`, `p75_er` |

---

### E. Sample SQL Queries for Inspection

Once connected, run these queries to inspect data distribution and benchmark statistics:

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

-- 2. Performance Comparison by Visual Complexity (Image Entropy)
SELECT 
    cr.visual_complexity,
    COUNT(f.creative_id) AS creative_count,
    ROUND(AVG(f.engagement_rate * 100)::numeric, 2) AS avg_er_percent,
    ROUND(AVG(f.click_through_rate * 100)::numeric, 2) AS avg_ctr_percent
FROM analytics.fact_creative_performance f
JOIN analytics.dim_creatives cr ON f.creative_id = cr.creative_id
GROUP BY cr.visual_complexity
ORDER BY avg_er_percent DESC;

-- 3. Industry & Advertiser Benchmarks
SELECT 
    advertiser,
    COUNT(DISTINCT campaign_id) AS total_campaigns,
    SUM(impressions) AS total_impressions,
    ROUND(AVG(engagement_rate * 100)::numeric, 2) AS avg_er_percent
FROM analytics.fact_creative_performance
GROUP BY advertiser
ORDER BY total_impressions DESC;
```

---

## 6. How to Interact with the Project

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

## 7. Data Version Control (DVC) & Pipeline Lineage

This project implements industry-standard **Data Version Control (DVC)** for data artifact tracking, pipeline stage caching, and experiment reproducibility.

### A. Tracked Datasets & Artifacts

| Artifact | Type | Storage Method | Description |
| :--- | :--- | :--- | :--- |
| `data/campaigns_inventory_updated.csv` | Raw Data (100 MB) | DVC Tracked (`.dvc`) | 422k+ raw impression & engagement logs |
| `data/briefing.csv` | Raw Data (111 KB) | DVC Tracked (`.dvc`) | Campaign briefs, objectives & budgets |
| `data/global_design_data.json` | Raw Data (4 MB) | DVC Tracked (`.dvc`) | Extracted creative UI & color data |
| `data/image_features.json` | Raw Data (25 KB) | DVC Tracked (`.dvc`) | Image design label metadata |
| `data/processed/*.parquet` | Processed Cache | Pipeline Output (`dvc.yaml`) | Vision embeddings & merged feature dataset |
| `models/*.pkl` | Model Weights | Pipeline Output (`dvc.yaml`) | Trained LightGBM multimodal model |

---

### B. Reproducible Pipeline (`dvc.yaml`)

The entire ML lifecycle is orchestrated via [`dvc.yaml`](file:///home/biruk-getaneh/projects/personal/AdTech-Creative-Performance-Prediction/dvc.yaml) with 4 deterministic stages:

```mermaid
flowchart LR
    classDef stageCard fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef outCard fill:#022c22,stroke:#10b981,stroke-width:2px,color:#f8fafc;

    V["👁️ stage: vision<br/>Extract ResNet50 & Heuristics"]
    F["⚙️ stage: features<br/>Merge & Feature Engineering"]
    B["🏆 stage: benchmark<br/>GroupKFold Model Evaluation"]
    T["🧠 stage: train<br/>Fit Final Multimodal Model"]

    V --> F --> B
    F --> T

    class V,F,B,T stageCard;
```

#### Key DVC Pipeline Commands:

```bash
# 1. Reproduce entire pipeline with Make (or dvc repro)
make dvc-repro

# 2. View model evaluation metrics across commits
make dvc-metrics

# 3. View pipeline status and cached stages
make dvc-status

# 4. Pull all versioned data from remote storage
dvc pull

# 5. Push data artifacts to remote storage
dvc push
```

---

### C. Configuring a Cloud Storage Remote

To sync large data files to cloud object storage (AWS S3, Google Cloud Storage, Azure Blob, or DAGsHub):

```bash
# Example: Add an AWS S3 Remote
dvc remote add -d s3-remote s3://my-adcreative-bucket/dvc-storage

# Example: Add a Google Cloud Storage Remote
dvc remote add -d gcs-remote gs://my-adcreative-bucket/dvc-storage

# Example: Add Google Drive or Local Remote
dvc remote add -d local-remote /path/to/shared/storage
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
