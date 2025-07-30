#!/usr/bin/env bash

set -e

# This script handles Django migrations intelligently:
# - If FORCE_FAKE_INITIAL=true: Uses --fake-initial (for existing databases)
# - If FORCE_FRESH_MIGRATE=true: Uses normal migration (for fresh databases) 
# - If SKIP_MIGRATIONS=true: Skips migration steps entirely
# - If FORCE_SYNCDB=true: Uses --run-syncdb to create tables without migration history
# - If FORCE_SYNCDB_UNSAFE=true: Uses --run-syncdb without data checks
# - Auto-detect (default): Checks if tables exist and chooses --fake-initial or migrate accordingly

bash scripts/tcp-port-wait.sh $DATABASE_HOST $DATABASE_PORT

# export env variable from file
if [ -e /JWT_PRIVATE_KEY_RSA_BUILDLY ]
then
  export JWT_PRIVATE_KEY_RSA_BUILDLY=`cat /JWT_PRIVATE_KEY_RSA_BUILDLY`
fi

if [ -e /JWT_PUBLIC_KEY_RSA_BUILDLY ]
then
  export JWT_PUBLIC_KEY_RSA_BUILDLY=`cat /JWT_PUBLIC_KEY_RSA_BUILDLY`
fi

echo $(date -u) "- Migrating"

# Allow manual override via environment variable
if [ "$FORCE_FAKE_INITIAL" = "true" ]; then
    echo $(date -u) "- FORCE_FAKE_INITIAL=true, using --fake-initial"
    python manage.py migrate --fake-initial
elif [ "$FORCE_FRESH_MIGRATE" = "true" ]; then
    echo $(date -u) "- FORCE_FRESH_MIGRATE=true, using normal migration"
    python manage.py makemigrations
    python manage.py migrate
elif [ "$FORCE_SYNCDB" = "true" ]; then
    echo $(date -u) "- FORCE_SYNCDB=true, using --run-syncdb to bypass migration issues"
    echo $(date -u) "- Running makemigrations..."
    python manage.py makemigrations
    echo $(date -u) "- Running migrate with --run-syncdb..."
    python manage.py migrate --run-syncdb
elif [ "$FORCE_SYNCDB_UNSAFE" = "true" ]; then
    echo $(date -u) "- FORCE_SYNCDB_UNSAFE=true, using --run-syncdb without data checks"
    python manage.py makemigrations
    python manage.py migrate --run-syncdb
elif [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping migration steps"
else
    # Auto-detect approach - with empty migrations table but existing tables
    echo $(date -u) "- Auto-detecting migration approach..."
    echo $(date -u) "- Running makemigrations..."
    
    if python manage.py makemigrations; then
        echo $(date -u) "- makemigrations succeeded"
        
        # Check if tables already exist
        TABLES_EXIST=$(python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute(\"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%_' LIMIT 1\")
        table_count = cursor.fetchone()[0]
        print(f'tables_exist:{table_count > 0}')
except Exception as e:
    print('tables_exist:false')
" 2>/dev/null)
        
        echo $(date -u) "- Table check result: $TABLES_EXIST"
        
        if echo "$TABLES_EXIST" | grep -q "tables_exist:true"; then
            echo $(date -u) "- Tables exist but migration history is empty, using --fake-initial"
            python manage.py migrate --fake-initial
        else
            echo $(date -u) "- No tables found, running normal migration"
            python manage.py migrate
        fi
    else
        echo $(date -u) "- makemigrations failed, this shouldn't happen with empty migration table"
        echo $(date -u) "- Trying --run-syncdb as fallback..."
        python manage.py migrate --run-syncdb
    fi
fi

echo $(date -u) "- Load Initial Data"
python manage.py loadinitialdata

echo $(date -u) "- Collect Static"
python manage.py collectstatic --no-input

echo $(date -u) "- Running the server"
gunicorn -b 0.0.0.0:8080 buildly.wsgi
