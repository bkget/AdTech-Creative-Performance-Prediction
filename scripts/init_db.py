import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

conn = psycopg2.connect(dsn="postgresql://postgres:postgres@localhost:5432/postgres")
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
cursor = conn.cursor()
try:
    cursor.execute("CREATE DATABASE adcreative_db")
    print("Created adcreative_db successfully")
except Exception as e:
    print(f"Database adcreative_db status/notice: {e}")
cursor.close()
conn.close()
