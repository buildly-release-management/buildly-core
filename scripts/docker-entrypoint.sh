#!/usr/bin/env bash

set -e

# This script handles Django migrations intelligently:
# - If FORCE_FAKE_INITIAL=true: Uses --fake-initial (for existing databases)
# - If FORCE_FRESH_MIGRATE=true: Uses normal migration (for fresh databases) 
# - If SKIP_MIGRATIONS=true: Skips migration steps entirely
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
    python manage.py makemigrations
    python manage.py migrate --fake-initial
elif [ "$FORCE_FRESH_MIGRATE" = "true" ]; then
    echo $(date -u) "- FORCE_FRESH_MIGRATE=true, using normal migration"
    python manage.py makemigrations
    python manage.py migrate
elif [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping migration steps"
else
    # Auto-detect migration state using Django's built-in commands
    echo $(date -u) "- Checking migration status..."
    
    # Generate migrations first
    python manage.py makemigrations
    
    # Check if we have unapplied migrations
    UNAPPLIED_MIGRATIONS=$(python manage.py showmigrations --plan | grep -c "^\[ \]" || echo "0")
    
    echo $(date -u) "- Found $UNAPPLIED_MIGRATIONS unapplied migrations"
    
    if [ "$UNAPPLIED_MIGRATIONS" -gt "0" ]; then
        # We have unapplied migrations - check if database has existing tables
        HAS_CORE_TABLES=$(python manage.py shell -c "
from django.db import connection
try:
    table_names = connection.introspection.table_names()
    if 'core_coreuser' in table_names:
        print('true')
    else:
        print('false')
except Exception:
    print('false')
" 2>/dev/null)
        
        if [ "$HAS_CORE_TABLES" = "true" ]; then
            echo $(date -u) "- Existing database with core tables detected, using --fake-initial"
            python manage.py migrate --fake-initial
        else
            echo $(date -u) "- Fresh database detected, running normal migration"
            python manage.py migrate
        fi
    else
        echo $(date -u) "- All migrations already applied, running migrate to ensure consistency"
        python manage.py migrate
    fi
fi

echo $(date -u) "- Load Initial Data"
python manage.py loadinitialdata

echo $(date -u) "- Collect Static"
python manage.py collectstatic --no-input

echo $(date -u) "- Running the server"
gunicorn -b 0.0.0.0:8080 buildly.wsgi
