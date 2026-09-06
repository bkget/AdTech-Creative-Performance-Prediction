#!/usr/bin/env bash
set -e

echo "=================================================="
echo " Starting AdTech Creative Intelligence Platform   "
echo "=================================================="

# 1. Wait for PostgreSQL
echo "Waiting for PostgreSQL database to be ready..."
python - <<'EOF'
import os
import time
import psycopg2

db_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres:5432/adcreative_db")
max_retries = 30
retry = 0

while retry < max_retries:
    try:
        conn = psycopg2.connect(db_url)
        conn.close()
        print(" Connected to PostgreSQL database successfully!")
        break
    except Exception as e:
        retry += 1
        time.sleep(1)
else:
    print(" Timed out waiting for PostgreSQL.")
    exit(1)
EOF

# 2. Automatically initialize database and load staging/analytics if not already loaded
echo "Checking and loading database tables & analytics..."
python -m src.db.load || echo "Warning: Database loader encountered a non-fatal warning."

# 3. Start FastAPI + Uvicorn server
echo "Starting FastAPI server on http://0.0.0.0:8000..."
exec uvicorn src.api.main:app --host 0.0.0.0 --port 8000
