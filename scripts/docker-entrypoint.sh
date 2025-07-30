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
    echo $(date -u) "- FORCE_MIGRATION_RESET=true, resetting migration history directly in database"
    
    # Bypass Django entirely and fix the migration table directly
    echo $(date -u) "- Clearing django_migrations table to reset migration history..."
    python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        # Delete the problematic core migration record
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'core' AND name = '0001_initial'\")
        print('Deleted core.0001_initial migration record')
        
        # Make sure auth migrations are marked as applied
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0001_initial', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0002_alter_permission_name_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0003_alter_user_email_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0004_alter_user_username_opts', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0005_alter_user_last_login_null', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0006_require_contenttypes_0002', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0007_alter_validators_add_error_messages', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0008_alter_user_username_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0009_alter_user_last_name_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0010_alter_group_name_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0011_update_proxy_permissions', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0012_alter_user_first_name_max_length', NOW()) ON CONFLICT DO NOTHING\")
        print('Ensured auth migrations are marked as applied')
        
        # Make sure contenttypes migrations are marked as applied
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('contenttypes', '0001_initial', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('contenttypes', '0002_remove_content_type_name', NOW()) ON CONFLICT DO NOTHING\")
        print('Ensured contenttypes migrations are marked as applied')
        
        # Make sure sessions migrations are marked as applied
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('sessions', '0001_initial', NOW()) ON CONFLICT DO NOTHING\")
        print('Ensured sessions migrations are marked as applied')
        
        print('Migration history reset complete')
except Exception as e:
    print(f'Error resetting migration history: {e}')
    print('Continuing anyway...')
"
    
    echo $(date -u) "- Now running makemigrations after fixing migration history..."
    python manage.py makemigrations || echo "makemigrations failed, continuing..."
    
    echo $(date -u) "- Running migrate with --fake-initial..."
    python manage.py migrate --fake-initial || echo "Fake initial failed, trying normal migrate..."
    
    echo $(date -u) "- Running final migrate to apply any remaining..."
    python manage.py migrate || echo "Final migrate had issues, but continuing..."
elif [ "$SKIP_MIGRATIONS" = "true" ]; then
    echo $(date -u) "- SKIP_MIGRATIONS=true, skipping migration steps"
else
    # For the auto-detect case, also handle the makemigrations failure
    echo $(date -u) "- Checking if makemigrations works..."
    
    # Test if makemigrations works
    if python manage.py makemigrations 2>&1 | grep -qi "InconsistentMigrationHistory"; then
        echo $(date -u) "- makemigrations failed with InconsistentMigrationHistory, fixing migration history directly..."
        
        # Bypass Django and fix the migration table directly
        echo $(date -u) "- Clearing problematic migration records from database..."
        python manage.py shell -c "
from django.db import connection
try:
    with connection.cursor() as cursor:
        # Delete the problematic core migration record
        cursor.execute(\"DELETE FROM django_migrations WHERE app = 'core' AND name = '0001_initial'\")
        print('Deleted core.0001_initial migration record')
        
        # Ensure auth migrations are marked as applied (key ones for dependency)
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('auth', '0012_alter_user_first_name_max_length', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('contenttypes', '0001_initial', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('contenttypes', '0002_remove_content_type_name', NOW()) ON CONFLICT DO NOTHING\")
        cursor.execute(\"INSERT INTO django_migrations (app, name, applied) VALUES ('sessions', '0001_initial', NOW()) ON CONFLICT DO NOTHING\")
        print('Ensured core Django app migrations are marked as applied')
except Exception as e:
    print(f'Error fixing migration history: {e}')
" || echo "Direct database fix failed, continuing..."
        
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
