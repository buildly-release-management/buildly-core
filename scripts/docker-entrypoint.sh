#!/usr/bin/env bash

set -e

# This script handles Django migrations intelligently:
# - If FORCE_FAKE_INITIAL=true: Uses --fake-initial (for existing databases)
# - If FORCE_FRESH_MIGRATE=true: Uses normal migration (for fresh databases) 
# - If SKIP_MIGRATIONS=true: Skips migration steps entirely
# - If FORCE_SYNCDB=true: Uses --run-syncdb, but checks for data first
# - If FORCE_SYNCDB_UNSAFE=true: Uses --run-syncdb without data checks
# - Auto-detect (default): Checks if database has existing tables and chooses appropriately

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
    
    # First clear migration records to fix any inconsistencies
    echo $(date -u) "- Clearing migration records to ensure clean state..."
    python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        print('Clearing problematic migration records...')
        cursor.execute(\"DELETE FROM django_migrations WHERE app IN ('admin', 'core', 'datamesh', 'gateway')\")
        print('Cleared migration records for all custom apps')
except Exception as e:
    print(f'Error clearing migration records: {e}')
" || echo "Failed to clear migration records"
    
    # Check if we have existing data
    HAS_DATA=$(python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        # Check if core user table exists and has data
        cursor.execute(\"SELECT COUNT(*) FROM core_coreuser LIMIT 1\")
        user_count = cursor.fetchone()[0]
        print(f'has_data:{user_count > 0}')
except Exception as e:
    print('has_data:false')
" 2>/dev/null)
    
    echo $(date -u) "- Data check result: $HAS_DATA"
    
    if echo "$HAS_DATA" | grep -q "has_data:true"; then
        echo $(date -u) "- Existing data detected, using --fake-initial to preserve data"
        python manage.py makemigrations
        python manage.py migrate --fake-initial
    else
        echo $(date -u) "- No critical data detected, safe to use --run-syncdb"
        python manage.py makemigrations
        python manage.py migrate --run-syncdb
    fi
elif [ "$FORCE_SYNCDB_UNSAFE" = "true" ]; then
    echo $(date -u) "- FORCE_SYNCDB_UNSAFE=true, using --run-syncdb without data checks"
    python manage.py makemigrations
    python manage.py migrate --run-syncdb
elif [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping migration steps"
else
    # Auto-detect approach with better error handling
    echo $(date -u) "- Auto-detecting migration approach..."
    
    # Try makemigrations first
    if python manage.py makemigrations; then
        echo $(date -u) "- makemigrations succeeded"
        
        # Try showmigrations to check state
        if python manage.py showmigrations --plan >/dev/null 2>&1; then
            echo $(date -u) "- Migration state is consistent, proceeding with normal migration"
            python manage.py migrate
        else
            echo $(date -u) "- Migration state inconsistent, using --run-syncdb"
            python manage.py migrate --run-syncdb
        fi
    else
        echo $(date -u) "- makemigrations failed, likely due to InconsistentMigrationHistory"
        echo $(date -u) "- Clearing migration records to fix inconsistent state..."
        
        # More comprehensive fix: clear all problematic migration records
        python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        print('Clearing all problematic migration records...')
        # Clear all admin migrations (they have dependency issues)
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'admin'\")
        # Clear all core migrations 
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'core'\")
        # Clear any other potentially problematic apps
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'datamesh'\")
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'gateway'\")
        print('Cleared all migration records for problematic apps')
        
        # Keep only the essential Django built-in migrations that we know work
        cursor.execute(\"SELECT COUNT(*) FROM django_migrations WHERE app IN ('auth', 'contenttypes', 'sessions')\")
        builtin_count = cursor.fetchone()[0]
        print(f'Kept {builtin_count} built-in Django migration records')
        
except Exception as e:
    print(f'Error clearing migration records: {e}')
" || echo "Failed to clear migration records"
        
        echo $(date -u) "- Now trying migration after clearing all problematic records..."
        python manage.py makemigrations || echo "makemigrations still failed"
        python manage.py migrate --run-syncdb || {
            echo $(date -u) "- --run-syncdb failed, trying --fake-initial as last resort"
            python manage.py migrate --fake-initial
        }
    fi
fi

echo $(date -u) "- Load Initial Data"
python manage.py loadinitialdata

echo $(date -u) "- Collect Static"
python manage.py collectstatic --no-input

echo $(date -u) "- Running the server"
gunicorn -b 0.0.0.0:8080 buildly.wsgi
