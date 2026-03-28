#!/bin/bash
# =============================================================================
# PostgreSQL initialization script
# Creates databases and users for GitLab and TeamCity
# =============================================================================

set -euo pipefail

echo "=== Initializing PostgreSQL databases ==="

# ---------------------------------------------------------------------------
# GitLab database
# ---------------------------------------------------------------------------
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="$POSTGRES_DB" <<-EOSQL
    -- Create user only if it differs from the superuser
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${GITLAB_DB_USER:-gitlab}') THEN
            CREATE ROLE ${GITLAB_DB_USER:-gitlab} WITH LOGIN PASSWORD '${GITLAB_DB_PASSWORD:-changeme}' CREATEDB;
        END IF;
    END
    \$\$;

    -- Create GitLab database
    SELECT 'CREATE DATABASE ${GITLAB_DB_NAME:-gitlabhq_production} OWNER ${GITLAB_DB_USER:-gitlab}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${GITLAB_DB_NAME:-gitlabhq_production}')
    \gexec

    GRANT ALL PRIVILEGES ON DATABASE ${GITLAB_DB_NAME:-gitlabhq_production} TO ${GITLAB_DB_USER:-gitlab};
EOSQL

# Enable required extensions for GitLab
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="${GITLAB_DB_NAME:-gitlabhq_production}" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS btree_gist;
EOSQL

# ---------------------------------------------------------------------------
# TeamCity database
# ---------------------------------------------------------------------------
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${TEAMCITY_DB_USER:-teamcity}') THEN
            CREATE ROLE ${TEAMCITY_DB_USER:-teamcity} WITH LOGIN PASSWORD '${TEAMCITY_DB_PASSWORD:-changeme}';
        END IF;
    END
    \$\$;

    SELECT 'CREATE DATABASE ${TEAMCITY_DB_NAME:-teamcity} OWNER ${TEAMCITY_DB_USER:-teamcity}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${TEAMCITY_DB_NAME:-teamcity}')
    \gexec

    GRANT ALL PRIVILEGES ON DATABASE ${TEAMCITY_DB_NAME:-teamcity} TO ${TEAMCITY_DB_USER:-teamcity};
EOSQL

echo "=== PostgreSQL initialization complete ==="
