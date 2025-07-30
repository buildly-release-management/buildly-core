#!/usr/bin/env bash

set -e

# This script handles Django migrations intelligently:
# - If FORCE_FAKE_INITIAL=true: Uses --fake-initial (for existing databases)
# - If FORCE_FRESH_MIGRATE=true: Uses normal migration (for fresh databases) 
# - If SKIP_MIGRATIONS=true: Skips migration steps entirely
# - If FORCE_MIGRATION_RESET=true: Handles inconsistent migration history by faking auth migrations
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
    python manage.py migrate
elif [ "$FORCE_MIGRATION_RESET" = "true" ]; then
    echo $(date -u) "- FORCE_MIGRATION_RESET=true, resetting migration history"
    # Skip makemigrations since it's failing due to inconsistent history
    # Just fix the database state directly
    echo $(date -u) "- Marking auth migrations as applied to fix dependency order..."
    python manage.py migrate auth --fake
    echo $(date -u) "- Marking contenttypes migrations as applied..."
    python manage.py migrate contenttypes --fake
    echo $(date -u) "- Marking sessions migrations as applied..."
    python manage.py migrate sessions --fake
    echo $(date -u) "- Now running makemigrations after fixing dependencies..."
    python manage.py makemigrations
    echo $(date -u) "- Running migrate with --fake-initial..."
    python manage.py migrate --fake-initial
elif [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping migration steps"
else
    # For the auto-detect case, also handle the makemigrations failure
    echo $(date -u) "- Checking if makemigrations works..."
    
    # Test if makemigrations works
    if python manage.py makemigrations 2>&1 | grep -qi "InconsistentMigrationHistory"; then
        echo $(date -u) "- makemigrations failed with InconsistentMigrationHistory, fixing dependencies first..."
        
        # Fix the dependency order by faking the base Django migrations
        echo $(date -u) "- Faking auth migrations to fix dependency order..."
        python manage.py migrate auth --fake || echo "Auth fake failed, continuing..."
        
        echo $(date -u) "- Faking contenttypes migrations..."
        python manage.py migrate contenttypes --fake || echo "Contenttypes fake failed, continuing..."
        
        echo $(date -u) "- Faking sessions migrations..."
        python manage.py migrate sessions --fake || echo "Sessions fake failed, continuing..."
        
        echo $(date -u) "- Now trying makemigrations again..."
        python manage.py makemigrations || echo "makemigrations still failed, continuing..."
        
        echo $(date -u) "- Running migrate with --fake-initial..."
        python manage.py migrate --fake-initial || echo "Fake initial failed, trying normal migrate..."
        
        echo $(date -u) "- Running final migrate to apply any remaining..."
        python manage.py migrate || echo "Final migrate had issues, but continuing..."
    else
        # makemigrations worked, proceed with normal detection logic
        echo $(date -u) "- makemigrations succeeded, checking migration status..."
        
        # Try to check migration status and capture any errors
        MIGRATION_CHECK_OUTPUT=$(python manage.py showmigrations --plan 2>&1)
        MIGRATION_CHECK_EXIT_CODE=$?
        
        if [ "$MIGRATION_CHECK_EXIT_CODE" -ne 0 ]; then
            echo $(date -u) "- showmigrations failed, using --fake-initial..."
            python manage.py migrate --fake-initial
        else
            # Normal migration flow
            UNAPPLIED_MIGRATIONS=$(echo "$MIGRATION_CHECK_OUTPUT" | grep -c "^\[ \]" || echo "0")
            echo $(date -u) "- Found $UNAPPLIED_MIGRATIONS unapplied migrations"
            
            if [ "$UNAPPLIED_MIGRATIONS" -gt "0" ]; then
                # Check if we have existing tables
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
                    echo $(date -u) "- Existing database detected, using --fake-initial"
                    python manage.py migrate --fake-initial
                else
                    echo $(date -u) "- Fresh database detected, running normal migration"
                    python manage.py migrate
                fi
            else
                echo $(date -u) "- All migrations applied, running migrate for consistency"
                python manage.py migrate
            fi
        fi
    fi
fi

echo $(date -u) "- Load Initial Data"
python manage.py loadinitialdata

echo $(date -u) "- Collect Static"
python manage.py collectstatic --no-input

echo $(date -u) "- Running the server"
gunicorn -b 0.0.0.0:8080 buildly.wsgi
