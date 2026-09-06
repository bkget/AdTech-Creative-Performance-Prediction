# AdTech Creative Performance Prediction
[![CI Pipeline](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml/badge.svg)](https://github.com/bkget/Ad-Challenge/actions/workflows/ci.yml)
This project is an end-to-end Machine Learning and Data Engineering platform built to predict the performance of digital advertising creatives *before* they are launched. 

It transforms raw campaign logs, tabular metadata, and actual image pixels (using deep learning) into a unified PostgreSQL database, serves the insights via a FastAPI backend, and visualizes them on a dynamic, interactive dashboard.

---

## 📑 Table of Contents
1. [The Basics: Understanding Ad Analysis](#1-the-basics-understanding-ad-analysis)
2. [Overall Architecture Flow](#2-overall-architecture-flow)
3. [Key Technical Decisions & Framework Choices](#3-key-technical-decisions--framework-choices)
4. [How to Run the Project (Docker & Local)](#4-how-to-run-the-project)
5. [🗄️ Database Connection & Schema Reference](#5-database-connection--schema-reference)
6. [How to Interact with the Project](#6-how-to-interact-with-the-project)

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
    subgraph RAW["📂 Raw Data"]
        A1["📋 briefing.csv\nCampaign budgets & dates"]
        A2["📊 inventory.csv\n350k+ ad events"]
        A3["🖼️ Creative Assets\n144 PNG images"]
        A4["🗂️ global_design_data.json\nColors, labels, text"]
    end

    subgraph PIPELINE["⚙️ ML Pipeline  ·  src/pipeline/run_all.py"]
        B1["Entity Resolution\nLink game_key → image"]
        B2["Vision Extraction\nResNet50 + Heuristics"]
        B3["Feature Engineering\nGroupKFold · PCA · LightGBM"]
    end

    subgraph STORE["🗄️ PostgreSQL Database"]
        C1["Campaigns · Creatives\nMetrics · Benchmarks"]
    end

    subgraph API["🚀 FastAPI  ·  src/api/main.py"]
        D1["/api/stats\n/api/benchmarks\n/api/predict"]
    end

    subgraph DASH["📱 Dashboard  ·  app/index.html"]
        E1["Interactive KPI Cards\nCreative Simulator"]
    end

    A1 & A2 & A3 & A4 --> B1
    B1 --> B2 --> B3
    B3 -->|"feature_dataset.parquet\nbenchmark_results.json"| C1
    C1 --> D1
    D1 -->|"REST JSON"| E1
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

---

## 4. How to Run the Project

You can run this project with a single Docker command (Option A, Recommended) or locally with Python (Option B).

---

### Option A: Running With Docker (Recommended — One Command)

No local Python, database, or virtual environment setup is required. Docker automatically boots PostgreSQL, initializes all schemas, loads the dataset and benchmarks, and starts the dashboard.

**Step 1: Start Everything**
```bash
docker compose up -d --build
```

**Step 2: View the Dashboard & Access Services**
- 📱 **Interactive Dashboard**: [http://localhost:8000](http://localhost:8000)
- 🚀 **Interactive API Docs (Swagger)**: [http://localhost:8000/docs](http://localhost:8000/docs)
- 🗄️ **PostgreSQL Database**: `localhost:5432` | DB: `adcreative_db` | User: `postgres` | Password: `postgres`
  *(See [Section 5](#5-database-connection--schema-reference) below for complete schema details & SQL inspection queries)*

---

#### Optional: Re-running the ML Pipeline in Docker
If you wish to re-train the models or re-compute feature extraction from scratch inside Docker:

```bash
# Force recompute the full pipeline inside Docker
docker compose run --rm pipeline --force

# Or execute inside the running API container
docker compose exec api python -m src.pipeline.run_all --force
```

*To shut everything down:* `docker compose down`

---

### Option B: Running Locally (Native Python)

If you prefer developing directly on your host machine:

**Prerequisites:** Python 3.11+ and PostgreSQL running on `localhost:5432` with credentials `postgres/postgres`.

```bash
# 1. Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
python -m pip install -r requirements.txt

# 2. Run the ML Pipeline
python -m src.pipeline.run_all --force

# 3. Initialize DB and load data
python scripts/init_db.py
python -m src.db.load

# 4. Start the API & Dashboard server
python -m uvicorn src.api.main:app --port 8000
```
Open **[http://localhost:8000](http://localhost:8000)** in your browser.

---

---

## 5. Database Connection & Schema Reference

When running with Docker, PostgreSQL is exposed on port `5432` with the database `adcreative_db`.

### A. Connection Credentials

| Parameter | Value (Host Access) | Value (Docker Network) |
| :--- | :--- | :--- |
| **Host** | `localhost` or `127.0.0.1` | `postgres` (or `adcreative_db`) |
| **Port** | `5432` | `5432` |
| **Database** | `adcreative_db` | `adcreative_db` |
| **Username** | `postgres` | `postgres` |
| **Password** | `postgres` | `postgres` |
| **Connection URI** | `postgresql://postgres:postgres@localhost:5432/adcreative_db` | `postgresql://postgres:postgres@postgres:5432/adcreative_db` |

---

### B. How to Connect

#### Option 1: Direct Terminal Access via Docker (Zero local tools needed)
```bash
docker compose exec postgres psql -U postgres -d adcreative_db
```

#### Option 2: Using Local `psql` Client
```bash
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d adcreative_db
```

#### Option 3: GUI Database Tools (DBeaver, pgAdmin, DataGrip, VS Code Extension)
- **Host**: `localhost`
- **Port**: `5432`
- **Database**: `adcreative_db`
- **Username**: `postgres`
- **Password**: `postgres`

---

### C. Database Architecture & Table Reference

The data warehouse uses a clean, two-layer schema design:

```mermaid
flowchart LR
    subgraph STG["📦 staging Schema (Raw Audit)"]
        S1["raw_inventory\n(350k+ events)"]
        S2["raw_briefing\n(Campaign metadata)"]
        S3["raw_design_metadata\n(Colors, labels, sizes)"]
        S4["raw_creative_assets\n(Image file registry)"]
        S5["raw_vision_features\n(ResNet50 + visual stats)"]
    end

    subgraph ANL["📊 analytics Schema (Curated Warehouse)"]
        A1["campaigns\n(Budgets & duration)"]
        A2["creatives\n(Visual features & slugs)"]
        A3["creative_metrics\n(Aggregated ER / CTR)"]
        A4["model_benchmarks\n(R², MAE, MAPE per model)"]
        A5["feature_importances\n(Top visual vs contextual)"]
    end

    STG -->|"SQL Aggregations & Joins"| ANL
```

#### 1. `staging` Schema (Raw, Unfiltered Audit Tables)
- **`staging.raw_inventory`**: Every raw ad event log (`impression`, `first_dropped`, `click-through-event`) with device, OS, country.
- **`staging.raw_briefing`**: Campaign budgets, agreed volumes, start/end dates, and objectives.
- **`staging.raw_design_metadata`**: Extracted global design features (dominant colors, text labels, video metadata).
- **`staging.raw_creative_assets`**: Physical `.png` asset mapping (`filename`, `request_id`, `creative_slug`).
- **`staging.raw_vision_features`**: Pre-computed 32-dimensional ResNet50 PCA embeddings and handcrafted visual metrics.

#### 2. `analytics` Schema (Curated Dimensional & Fact Tables)
- **`analytics.campaigns`**: Cleaned, deduplicated campaign dimensions and normalized financial metrics.
- **`analytics.creatives`**: Creative master table linking images, aspect ratios, brightness, saturation, and visual entropy.
- **`analytics.creative_metrics`**: Aggregated performance fact table (impressions, clicks, engagements, ER, CTR) grouped by campaign, creative, and user context.
- **`analytics.model_benchmarks`**: Cross-validation results across Baseline, Tabular, Vision, and Multimodal models.
- **`analytics.feature_importances`**: Ranked feature importance categorized into *Visual* vs *Contextual*.

---

### D. Useful SQL Queries to Inspect the Data

Once connected via `psql`:

```sql
-- 1. List all schemas
\dn

-- 2. List all tables across staging and analytics
\dt staging.*
\dt analytics.*

-- 3. View model benchmark scores (R², MAE, MAPE)
SELECT model_name, r2, mae, rmse, mape, n_features 
FROM analytics.model_benchmarks 
ORDER BY r2 DESC;

-- 4. View top 10 most influential features
SELECT feature_name, category, importance_score 
FROM analytics.feature_importances 
ORDER BY importance_score DESC 
LIMIT 10;

-- 5. Inspect top performing creatives by engagement rate
SELECT 
    c.creative_slug,
    m.n_impressions,
    m.n_engagements,
    ROUND(m.engagement_rate::numeric * 100, 2) AS er_percent,
    ROUND(m.click_through_rate::numeric * 100, 2) AS ctr_percent,
    c.brightness_mean,
    c.saturation_mean
FROM analytics.creative_metrics m
JOIN analytics.creatives c ON c.game_key = m.game_key
WHERE m.n_impressions >= 100
ORDER BY m.engagement_rate DESC
LIMIT 10;

-- 6. Check total event counts in staging
SELECT type, COUNT(*) AS event_count 
FROM staging.raw_inventory 
GROUP BY type;
```

---

## 6. How to Interact with the Project

Once the Dashboard (`http://localhost:8000`) is open, here is how you interact with it and understand the results:

1.  **The Hero KPIs:** Notice the top numbers. The platform successfully linked hundreds of thousands of events to their exact creative image assets.
2.  **The Benchmark Chart:** This is the core scientific result. Click the "R² Score" button. You will see that the `Tabular` model (context only) performs decently, but the `Multimodal` model (context + image pixels) performs significantly better (a ~19% relative jump). This proves that **visual aesthetics drive engagement**.
3.  **Feature Importance:** Look at the purple and teal bars. This explains *how* the AI makes decisions. Campaign parameters (like budget and duration) are the strongest drivers, but visual elements like image brightness and deep ResNet features are right behind them.
4.  **The Creative Performance Simulator:** Scroll to the bottom. Change the sliders (e.g., increase Brightness, switch Device to Smartphone, toggle Video on). Watch the Predicted ER and CTR update instantly. **This is hitting the FastAPI backend in real-time**, proving the architecture works end-to-end. 

For static analysis charts (perfect for slide decks), check the `results/charts/` folder after running the pipeline!

