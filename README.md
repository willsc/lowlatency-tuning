# Low-Latency Tuning CI/CD Stack

A Docker Compose stack providing a complete CI/CD pipeline with monitoring and observability. The stack includes GitLab for source control, TeamCity for builds, Octopus Deploy for deployments, and a full Prometheus/Grafana/ClickHouse monitoring layer.

## Services Overview

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| GitLab CE | `gitlab/gitlab-ce:17.6.2-ce.0` | 8929 (HTTP), 2224 (SSH) | Source control & CI |
| TeamCity Server | `jetbrains/teamcity-server:2024.12.1` | 8111 | Build server |
| TeamCity Agents (x3) | `jetbrains/teamcity-agent:2024.12.1-linux-sudo` | - | Build agents |
| Octopus Deploy | `octopusdeploy/octopusdeploy:2024.4` | 8080 | Deployment automation |
| PostgreSQL | `postgres:16-alpine` | 5432 (internal) | Database for GitLab & TeamCity |
| MSSQL Server | `mcr.microsoft.com/mssql/server:2022-latest` | 1433 (internal) | Database for Octopus Deploy |
| Redis | `redis:7.4-alpine` | 6379 (internal) | Cache for GitLab |
| ClickHouse | `clickhouse/clickhouse-server:24.11-alpine` | 8123 (HTTP), 9000 (native) | Analytics database |
| Prometheus | `prom/prometheus:v3.1.0` | 9090 | Metrics collection |
| Grafana | `grafana/grafana:11.4.0` | 3000 | Dashboards & visualization |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 (internal) | Host metrics |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.51.0` | 8080 (internal) | Container metrics |
| Tabix | `spoonest/clickhouse-tabix-web-client:stable` | 8124 | ClickHouse web UI |

## Quick Start

```bash
# From the CICD-stack directory (one level up):
cp .env.example .env
# Edit .env and change all passwords from their defaults

# Start the stack:
docker compose -f lowlatency-tuning/docker-compose.yml up -d

# Check health:
docker compose -f lowlatency-tuning/docker-compose.yml ps
```

> **Note:** GitLab takes ~5 minutes to fully initialize. TeamCity and Octopus Deploy take ~3 minutes each.

## Accessing Services

### GitLab (Source Control)

| | |
|---|---|
| **URL** | `http://<host>:8929` |
| **Username** | `root` |
| **Password** | Value of `GITLAB_ROOT_PASSWORD` in `.env` (default: `Admin123!`) |
| **SSH** | `ssh://git@<host>:2224` |

### TeamCity (Build Server)

| | |
|---|---|
| **URL** | `http://<host>:8111` |
| **Database** | PostgreSQL (auto-configured via init script) |
| **DB User** | Value of `TEAMCITY_DB_USER` in `.env` (default: `admin`) |
| **DB Password** | Value of `TEAMCITY_DB_PASSWORD` in `.env` (default: `admin`) |

TeamCity requires first-time setup through the web UI. The database connection is pre-configured via environment variables. Three build agents auto-register with the server.

### Octopus Deploy (Deployments)

| | |
|---|---|
| **URL** | `http://<host>:8080` |
| **Admin Username** | Value of `OCTOPUS_ADMIN_USERNAME` in `.env` (default: `admin`) |
| **Admin Password** | Value of `OCTOPUS_ADMIN_PASSWORD` in `.env` (default: `Admin123!`) |
| **Master Key** | Value of `OCTOPUS_MASTER_KEY` in `.env` (default: `esHWiP/Ike+4i2Z+Oouttg==`) |

> **Important:** The master key is required to restore Octopus from backup. Store it securely.

### Grafana (Dashboards)

| | |
|---|---|
| **URL** | `http://<host>:3000` |
| **Username** | Value of `GRAFANA_ADMIN_USER` in `.env` (default: `admin`) |
| **Password** | Value of `GRAFANA_ADMIN_PASSWORD` in `.env` (default: `admin`) |

Pre-configured datasources:
- **Prometheus** (default) - metrics from all services
- **ClickHouse** - analytics data via the `grafana-clickhouse-datasource` plugin

### Prometheus (Metrics)

| | |
|---|---|
| **URL** | `http://<host>:9090` |
| **Auth** | None (unauthenticated) |
| **Retention** | 30 days / 10GB (configurable via `PROMETHEUS_RETENTION` / `PROMETHEUS_RETENTION_SIZE`) |

Scrape targets: Prometheus, Node Exporter, cAdvisor, GitLab, TeamCity, ClickHouse, Grafana, PostgreSQL, Redis.

### ClickHouse (Analytics DB)

| | |
|---|---|
| **HTTP API** | `http://<host>:8123` |
| **Native Protocol** | `<host>:9000` |
| **Username** | Value of `CLICKHOUSE_USER` in `.env` (default: `admin`) |
| **Password** | Value of `CLICKHOUSE_PASSWORD` in `.env` (default: `admin`) |
| **Web UI (Tabix)** | `http://<host>:8124` |

ClickHouse user profiles: `default` (full access), `readonly`, `grafana` (read-only, used by Grafana datasource).

### PostgreSQL (Database)

| | |
|---|---|
| **Host** | `postgres` (internal only, not exposed to host) |
| **Port** | 5432 |
| **Superuser** | Value of `POSTGRES_USER` / `POSTGRES_PASSWORD` in `.env` (default: `admin` / `admin`) |

Databases created automatically by `scripts/init-postgres.sh`:
- `gitlabhq_production` - GitLab database
- `teamcity` - TeamCity database

### MSSQL Server (Database)

| | |
|---|---|
| **Host** | `mssql` (internal only, not exposed to host) |
| **Port** | 1433 |
| **SA Password** | Value of `MSSQL_SA_PASSWORD` in `.env` (default: `Admin123!`) |
| **Edition** | Express |

Used exclusively by Octopus Deploy.

## Network Architecture

The stack uses three isolated Docker networks:

| Network | Subnet | Purpose | Services |
|---------|--------|---------|----------|
| `cicd` | 172.28.0.0/16 | CI/CD pipeline traffic | GitLab, TeamCity (server + agents), Octopus, Prometheus |
| `backend` | 172.29.0.0/16 | Database access (internal) | PostgreSQL, Redis, MSSQL, ClickHouse, GitLab, TeamCity, Octopus |
| `monitoring` | 172.30.0.0/16 | Metrics & dashboards | Prometheus, Grafana, Node Exporter, cAdvisor, Tabix, ClickHouse, TeamCity, Octopus |

The `backend` network is marked as internal - services on it cannot reach the outside network directly.

## Resource Requirements

Total resource limits across all containers:

| Resource | Allocation |
|----------|------------|
| **CPU** | ~29 cores |
| **Memory** | ~36.4 GB |

Largest consumers: GitLab (4 CPU / 6 GB), TeamCity Server (4 CPU / 4 GB), ClickHouse (4 CPU / 4 GB), Octopus (2 CPU / 4 GB).

## Alerting

Prometheus alert rules are defined in `configs/prometheus/alert_rules.yml`:

- **Service health:** ServiceDown, HighMemoryUsage (>90%), HighCPUUsage (>90%), DiskSpaceLow (<10%)
- **Container health:** ContainerHighCPU (>80%), ContainerHighMemory (>90%), ContainerRestarting (>3/hour)
- **ClickHouse:** ReplicaLag (>300s), RejectedInserts
- **GitLab:** HighResponseTime (p95 >10s)

## Configuration Files

```
lowlatency-tuning/
├── docker-compose.yml
├── scripts/
│   └── init-postgres.sh              # Creates GitLab & TeamCity databases
└── configs/
    ├── prometheus/
    │   ├── prometheus.yml             # Scrape targets & global settings
    │   └── alert_rules.yml            # Alert definitions
    ├── grafana/provisioning/
    │   ├── datasources/datasources.yml  # Prometheus + ClickHouse datasources
    │   └── dashboards/dashboards.yml    # Dashboard provisioning config
    └── clickhouse/
        ├── config.xml                 # Server config (connections, memory, logging)
        └── users.xml                  # User profiles (default, readonly, grafana)
```

## Environment Variables

All configuration is driven by the `.env` file in the parent `CICD-stack/` directory. Copy `.env.example` to `.env` and customize before starting.

See `.env.example` for the full list of configurable variables with descriptions and default values.

## Security Notes

- **Change all default passwords** before running in any shared or production environment.
- The default passwords (`admin`, `Admin123!`) are for local development only.
- The Octopus Deploy master key should be generated uniquely per deployment and stored securely.
- PostgreSQL and MSSQL are not exposed to the host by default (internal network only).
- No TLS is configured between services - add a reverse proxy for HTTPS in production.
- Prometheus and Tabix have no authentication - restrict access at the network level.
