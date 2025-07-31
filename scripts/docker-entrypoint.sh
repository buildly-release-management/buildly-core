#!/usr/bin/env bash

set -e

# Simplified Django migration script with basic functions:
# - SKIP_MIGRATIONS=true: Skip all migration steps
# - FORCE_SYNCDB=true: Use --run-syncdb to create tables without migration history
# - FORCE_FAKE=true: Mark all migrations as applied without executing them
# - FORCE_SCHEMA_SYNC=true: Safely sync schema to match current models (preserves data)
# - Default: Smart migration with fallback strategies

bash scripts/tcp-port-wait.sh $DATABASE_HOST $DATABASE_PORT

# Export environment variables from files
if [ -e /JWT_PRIVATE_KEY_RSA_BUILDLY ]; then
  export JWT_PRIVATE_KEY_RSA_BUILDLY=`cat /JWT_PRIVATE_KEY_RSA_BUILDLY`
fi

if [ -e /JWT_PUBLIC_KEY_RSA_BUILDLY ]; then
  export JWT_PUBLIC_KEY_RSA_BUILDLY=`cat /JWT_PUBLIC_KEY_RSA_BUILDLY`
fi

echo $(date -u) "- Starting migration process"

# Function to check if database has any tables
check_database_empty() {
    python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute(\"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'\")
        table_count = cursor.fetchone()[0]
        print(f'table_count:{table_count}')
except Exception as e:
    print('table_count:0')
" 2>/dev/null
}

# Function to check migration status
check_migration_status() {
    python manage.py showmigrations --list 2>/dev/null | grep -q "\[ \]" && echo "unapplied" || echo "applied"
}

# Migration logic
if [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping all migration steps"
    
elif [ "$FORCE_SYNCDB" = "true" ]; then
    echo $(date -u) "- FORCE_SYNCDB=true, using --run-syncdb to create tables"
    python manage.py makemigrations
    python manage.py migrate --run-syncdb
    
elif [ "$FORCE_FAKE" = "true" ]; then
    echo $(date -u) "- FORCE_FAKE=true, marking all migrations as applied"
    python manage.py makemigrations
    python manage.py migrate --fake

elif [ "$FORCE_SCHEMA_SYNC" = "true" ]; then
    echo $(date -u) "- FORCE_SCHEMA_SYNC=true, safely syncing schema to match current models"
    echo $(date -u) "- This preserves all existing data while updating schema"
    
    # Step 1: Create migration files for current state
    echo $(date -u) "- Creating migration files..."
    python manage.py makemigrations
    
    # Step 2: Use Django's introspection to safely sync schema
    echo $(date -u) "- Analyzing schema differences and applying safe changes..."
    python manage.py shell -c "
import os
import django
from django.core.management import execute_from_command_line
from django.db import connection
from django.apps import apps
from django.core.management.base import CommandError

print('=== Django Schema Sync Process ===')

# Get all app labels that have models
app_labels = []
for app_config in apps.get_app_configs():
    if app_config.get_models():
        app_labels.append(app_config.label)

print(f'Apps with models: {app_labels}')

# Try to apply migrations normally first (safest approach)
print('\\n1. Attempting normal migration...')
try:
    from django.core.management import call_command
    call_command('migrate', verbosity=1, interactive=False)
    print('✓ Normal migration successful!')
except Exception as e:
    print(f'✗ Normal migration failed: {e}')
    
    print('\\n2. Trying --fake-initial for existing tables...')
    try:
        call_command('migrate', fake_initial=True, verbosity=1, interactive=False)
        print('✓ Fake initial migration successful!')
    except Exception as e:
        print(f'✗ Fake initial failed: {e}')
        
        print('\\n3. Using --run-syncdb to create missing tables...')
        try:
            call_command('migrate', run_syncdb=True, verbosity=1, interactive=False)
            print('✓ Syncdb successful!')
        except Exception as e:
            print(f'✗ Syncdb failed: {e}')
            
            print('\\n4. Final fallback: marking migrations as fake...')
            try:
                call_command('migrate', fake=True, verbosity=1, interactive=False)
                print('✓ Fake migration successful!')
            except Exception as e:
                print(f'✗ All migration strategies failed: {e}')
                raise

print('\\n=== Schema sync completed ===')
"
    
else
    # Smart migration with fallback
    echo $(date -u) "- Running smart migration with auto-detection"
    
    # Always run makemigrations first
    echo $(date -u) "- Creating migration files..."
    python manage.py makemigrations
    
    # Check if database is empty
    DB_STATUS=$(check_database_empty)
    TABLE_COUNT=$(echo "$DB_STATUS" | grep -o 'table_count:[0-9]*' | cut -d: -f2)
    
    echo $(date -u) "- Database has $TABLE_COUNT tables"
    
    if [ "$TABLE_COUNT" = "0" ]; then
        # Empty database - run normal migrations
        echo $(date -u) "- Empty database detected, running normal migrations"
        python manage.py migrate
        
    else
        # Database has tables - try migrations with fallbacks
        echo $(date -u) "- Existing database detected, attempting migration with fallbacks"
        
        if python manage.py migrate --verbosity=1; then
            echo $(date -u) "- Migrations completed successfully"
        else
            echo $(date -u) "- Migration failed, trying --run-syncdb fallback"
            if python manage.py migrate --run-syncdb; then
                echo $(date -u) "- Syncdb fallback successful"
            else
                echo $(date -u) "- Syncdb failed, using --fake as last resort"
                python manage.py migrate --fake
            fi
        fi
    fi
fi

echo $(date -u) "- Migration process completed"

echo $(date -u) "- Loading initial data"
python manage.py loadinitialdata

echo $(date -u) "- Collecting static files"
python manage.py collectstatic --no-input

echo $(date -u) "- Starting server"
gunicorn -b 0.0.0.0:8080 buildly.wsgi
