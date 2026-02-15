#!/bin/bash
set -e

echo "Starting Horilla HR..."

# Wait for Supabase PostgreSQL using Python (no external tools needed)
python << END
import os
import sys
import time
import psycopg2
from urllib.parse import urlparse

db_url = os.environ.get('DATABASE_URL')
if not db_url:
    print("❌ DATABASE_URL not set")
    sys.exit(1)

parsed = urlparse(db_url)
max_retries = 30
for i in range(max_retries):
    try:
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port or 5432,
            user=parsed.username,
            password=parsed.password,
            database=parsed.path[1:],
            sslmode='require'
        )
        conn.close()
        print("✅ Supabase is ready!")
        sys.exit(0)
    except Exception as e:
        print(f"⏳ Waiting for Supabase... ({i+1}/{max_retries})")
        time.sleep(2)
print("❌ Failed to connect to Supabase")
sys.exit(1)
END

# Run ONLY safe production commands
python manage.py migrate --noinput          # ← SAFE
python manage.py collectstatic --noinput    # ← SAFE

# NEVER run: python manage.py makemigrations

echo "Starting server..."
exec "$@"
