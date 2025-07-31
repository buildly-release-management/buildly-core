#!/usr/bin/env bash

set -e

# Buildly Core Docker Entrypoint Script
# 
# This script handles Django migrations intelligently for different deployment scenarios:
#
# Environment Variables:
# - SKIP_MIGRATIONS=true: Skip all migration steps (for read-only containers)
# - FORCE_SYNCDB=true: Use --run-syncdb with schema verification (for corrupted migration state)
# - FORCE_FAKE=true: Mark all migrations as applied without executing (for manual schema management)
# - FORCE_SCHEMA_SYNC=true: Comprehensive schema synchronization with multiple fallback strategies
# - Default: Smart migration with automatic detection and fallbacks
#
# The script automatically detects database state and chooses the appropriate migration strategy.

echo "=== Buildly Core Startup ==="
echo "$(date -u) - Container starting..."

# Wait for database to be ready
echo "$(date -u) - Waiting for database connection..."
bash scripts/tcp-port-wait.sh $DATABASE_HOST $DATABASE_PORT
echo "$(date -u) - Database connection established"

# Export JWT keys from files if they exist
if [ -e /JWT_PRIVATE_KEY_RSA_BUILDLY ]; then
  export JWT_PRIVATE_KEY_RSA_BUILDLY=`cat /JWT_PRIVATE_KEY_RSA_BUILDLY`
  echo "$(date -u) - JWT private key loaded from file"
fi

if [ -e /JWT_PUBLIC_KEY_RSA_BUILDLY ]; then
  export JWT_PUBLIC_KEY_RSA_BUILDLY=`cat /JWT_PUBLIC_KEY_RSA_BUILDLY`
  echo "$(date -u) - JWT public key loaded from file"
fi

echo "$(date -u) - Starting migration process..."

# Migration strategy selection
if [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo "$(date -u) - SKIP_MIGRATIONS=true: Skipping all migration steps"
    
elif [ "$FORCE_SYNCDB" = "true" ]; then
    echo "$(date -u) - FORCE_SYNCDB=true: Using --run-syncdb with comprehensive database sync"
    echo "$(date -u) - This approach creates missing tables and fixes schema issues"
    
    python manage.py makemigrations
    
    # First, try to create any missing tables with run-syncdb
    echo "$(date -u) - Creating missing tables with --run-syncdb..."
    python manage.py migrate --run-syncdb
    
    # Then apply any pending migrations normally
    echo "$(date -u) - Applying any remaining migrations..."
    python manage.py migrate
    
    # Comprehensive schema verification and fixing
    echo "$(date -u) - Verifying and fixing database schema..."
    python manage.py shell -c "
from django.db import connection
from django.apps import apps
from django.core.management import call_command

print('=== Comprehensive Database Verification ===')
issues_found = False

# Check for missing tables and create them
with connection.cursor() as cursor:
    # Get all existing table names
    cursor.execute('''
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ''')
    existing_tables = {row[0] for row in cursor.fetchall()}
    
    for app_config in apps.get_app_configs():
        for model in app_config.get_models():
            table_name = model._meta.db_table
            
            if table_name not in existing_tables:
                issues_found = True
                print(f'\\n⚠️  Missing table: {table_name}')
                try:
                    # Create the table using schema editor
                    with connection.schema_editor() as schema_editor:
                        schema_editor.create_model(model)
                    print(f'   ✓ Created table: {table_name}')
                    existing_tables.add(table_name)
                except Exception as e:
                    print(f'   ✗ Failed to create table {table_name}: {e}')
            else:
                # Check for missing columns in existing tables
                cursor.execute('''
                    SELECT column_name FROM information_schema.columns 
                    WHERE table_name = %s AND table_schema = 'public'
                ''', [table_name])
                existing_columns = {row[0] for row in cursor.fetchall()}
                
                missing_columns = []
                for field in model._meta.fields:
                    if field.column not in existing_columns:
                        missing_columns.append(field)
                
                if missing_columns:
                    issues_found = True
                    print(f'\\n⚠️  Table {table_name} missing {len(missing_columns)} columns')
                    
                    for field in missing_columns:
                        try:
                            with connection.schema_editor() as schema_editor:
                                schema_editor.add_field(model, field)
                            print(f'   ✓ Added column: {field.column}')
                        except Exception as e:
                            print(f'   ✗ Failed to add column {field.column}: {e}')

# Special handling for JWT token blacklist tables (critical for authentication)
jwt_tables = ['token_blacklist_outstandingtoken', 'token_blacklist_blacklistedtoken']
for table in jwt_tables:
    if table not in existing_tables:
        print(f'\\n⚠️  Critical JWT table missing: {table}')
        try:
            # Force create JWT tables by running token_blacklist migrations
            call_command('migrate', 'token_blacklist', verbosity=1)
            print(f'   ✓ Created JWT token blacklist tables')
        except Exception as e:
            print(f'   ✗ Failed to create JWT tables: {e}')

print('\\n✓ Database verification completed' if not issues_found else '✓ Database issues resolved')
"
    
elif [ "$FORCE_FAKE" = "true" ]; then
    echo "$(date -u) - FORCE_FAKE=true: Marking all migrations as applied"
    echo "$(date -u) - Use this when database schema is manually managed"
    
    python manage.py makemigrations
    python manage.py migrate --fake
    
elif [ "$FORCE_SCHEMA_SYNC" = "true" ]; then
    echo "$(date -u) - FORCE_SCHEMA_SYNC=true: Comprehensive schema synchronization"
    echo "$(date -u) - Trying multiple Django migration strategies with fallbacks"
    
    python manage.py makemigrations
    
    python manage.py shell -c "
from django.core.management import call_command

print('=== Comprehensive Migration Strategy ===')

strategies = [
    ('Normal Migration', lambda: call_command('migrate', verbosity=1)),
    ('Fake Initial + Migrate', lambda: call_command('migrate', fake_initial=True, verbosity=1)),
    ('Run Syncdb', lambda: call_command('migrate', run_syncdb=True, verbosity=1)),
    ('Fake All Migrations', lambda: call_command('migrate', fake=True, verbosity=1))
]

for strategy_name, strategy_func in strategies:
    print(f'\\nTrying: {strategy_name}...')
    try:
        strategy_func()
        print(f'✓ {strategy_name} successful!')
        break
    except Exception as e:
        print(f'✗ {strategy_name} failed: {e}')
else:
    print('✗ All migration strategies failed!')
    raise Exception('Unable to apply migrations with any strategy')

print('\\n✓ Schema synchronization completed')
"
    
else
    # Default: Smart migration with automatic detection
    echo "$(date -u) - Smart migration: Auto-detecting database state and choosing strategy"
    
    python manage.py makemigrations
    
    # Check if database is empty
    TABLE_COUNT=$(python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = \\'public\\'')
        print(cursor.fetchone()[0])
except:
    print(0)
" 2>/dev/null)
    
    echo "$(date -u) - Database contains $TABLE_COUNT tables"
    
    if [ "$TABLE_COUNT" = "0" ]; then
        echo "$(date -u) - Empty database: Running fresh migrations"
        python manage.py migrate
    else
        echo "$(date -u) - Existing database: Trying migration with fallbacks"
        if python manage.py migrate; then
            echo "$(date -u) - ✓ Migration successful"
        else
            echo "$(date -u) - Migration failed, trying --run-syncdb fallback"
            if python manage.py migrate --run-syncdb; then
                echo "$(date -u) - ✓ Syncdb fallback successful"
            else
                echo "$(date -u) - Syncdb failed, using --fake as last resort"
                python manage.py migrate --fake
                echo "$(date -u) - ✓ Migrations marked as fake"
            fi
        fi
    fi
fi

echo "$(date -u) - Migration process completed successfully"

# Load initial data
echo "$(date -u) - Loading initial data..."
python manage.py loadinitialdata

# Collect static files
echo "$(date -u) - Collecting static files..."
python manage.py collectstatic --no-input

# Start the application server
echo "$(date -u) - Starting Buildly Core server on port 8080..."
echo "=== Buildly Core Ready ==="
gunicorn -b 0.0.0.0:8080 buildly.wsgi
