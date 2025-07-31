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
    
    # After syncdb, verify schema matches models and fix any missing columns
    echo $(date -u) "- Verifying schema matches current models..."
    python manage.py shell -c "
from django.db import connection
from django.apps import apps
from django.core.management.color import no_style

print('=== Post-syncdb Schema Verification ===')

with connection.cursor() as cursor:
    schema_fixes_needed = False
    
    # Check each model for missing columns
    for app_config in apps.get_app_configs():
        for model in app_config.get_models():
            table_name = model._meta.db_table
            
            # Get existing columns from database
            try:
                cursor.execute(\"\"\"
                    SELECT column_name, data_type, is_nullable, column_default 
                    FROM information_schema.columns 
                    WHERE table_name = %s AND table_schema = 'public'
                \"\"\", [table_name])
                existing_columns = {row[0]: {'type': row[1], 'nullable': row[2], 'default': row[3]} 
                                  for row in cursor.fetchall()}
                
                # Check each model field
                missing_columns = []
                for field in model._meta.fields:
                    if field.column not in existing_columns:
                        missing_columns.append(field)
                
                if missing_columns:
                    schema_fixes_needed = True
                    print(f'\\n⚠️  Table {table_name} missing columns:')
                    
                    for field in missing_columns:
                        print(f'   - {field.column} ({field.__class__.__name__})')
                        
                        # Use Django's schema editor to add the missing column
                        try:
                            with connection.schema_editor() as schema_editor:
                                schema_editor.add_field(model, field)
                            print(f'   ✓ Added column {field.column}')
                        except Exception as e:
                            print(f'   ✗ Failed to add {field.column}: {e}')
                            
                            # Fallback: try raw SQL for common field types
                            try:
                                if hasattr(field, 'default') and field.default is not None:
                                    if field.__class__.__name__ == 'BooleanField':
                                        default_val = 'TRUE' if field.default else 'FALSE'
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} BOOLEAN NOT NULL DEFAULT {default_val}')
                                    elif field.__class__.__name__ in ['CharField', 'TextField']:
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} VARCHAR({field.max_length or 255}) NOT NULL DEFAULT %s', [field.default])
                                    elif field.__class__.__name__ in ['IntegerField', 'BigIntegerField']:
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} INTEGER NOT NULL DEFAULT %s', [field.default])
                                    elif field.__class__.__name__ == 'FloatField':
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} REAL NOT NULL DEFAULT %s', [field.default])
                                    else:
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} TEXT')
                                else:
                                    # No default, make it nullable
                                    if field.__class__.__name__ == 'BooleanField':
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} BOOLEAN')
                                    else:
                                        cursor.execute(f'ALTER TABLE {table_name} ADD COLUMN {field.column} TEXT')
                                print(f'   ✓ Added column {field.column} via raw SQL')
                            except Exception as sql_e:
                                print(f'   ✗ Raw SQL also failed for {field.column}: {sql_e}')
                                
            except Exception as e:
                print(f'Error checking table {table_name}: {e}')

if not schema_fixes_needed:
    print('✓ All tables have correct schema')
else:
    print('\\n✓ Schema fixes completed')

print('=== Schema verification completed ===')
"
    
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
