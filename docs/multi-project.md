# Multi-Project Management Guide

> Managing multiple homelab services on a single Mac Pro 6,1 (2013) using the Hawk methodology.

---

## Directory Structure

All homelab projects live under `/opt/stacks/`, one directory per project:

```
/opt/stacks/
├── cloudflared/              # Cloudflare Tunnel
│   ├── docker-compose.yml
│   └── config.yml
├── transmission/             # PT download client (core, always-on)
│   ├── docker-compose.yml
│   └── config/
├── postgres/                 # Shared PostgreSQL instance
│   ├── docker-compose.yml
│   └── data/
├── redis/                    # Shared Redis instance
│   ├── docker-compose.yml
│   └── data/
├── my-web-app/               # Example app project
│   ├── docker-compose.yml
│   ├── deploy.sh
│   ├── rollback.sh
│   ├── pre-deploy-check.sh
│   └── ...
├── my-api/                   # Another app project
│   └── ...
└── monitoring/               # Uptime Kuma, healthchecks
    └── ...
```

### Conventions

- **Project name** = directory name = container name prefix (`hawk-<project>`)
- **One `docker-compose.yml` per project** — no monolithic compose file
- **Each project is independently deployable** — `cd /opt/stacks/<project> && bash deploy.sh`

---

## Shared Network: `app-net`

All containers join a shared Docker bridge network called `app-net`. This enables inter-service communication without exposing ports to the host.

```bash
# Create the shared network (one-time setup)
docker network create app-net

# Verify
docker network inspect app-net
```

Each project's `docker-compose.yml` declares:

```yaml
networks:
  app-net:
    external: true
```

Containers on `app-net` can reach each other by container name:

```bash
# From inside any container:
curl http://hawk-postgres:5432
redis-cli -h hawk-redis
```

---

## Port Allocation

Ports are a finite resource. Document every allocation to avoid conflicts.

### Port Range: 8000–9999

| Port  | Service              | Status   |
|-------|----------------------|----------|
| 52888 | Colima SSH forwarder | Reserved |
| 8080  | (default/template)   | Available |
| 9090  | Uptime Kuma          | Taken    |
| 9091  | Transmission UI      | Taken    |
| 5432  | PostgreSQL (internal)| Shared   |
| 6379  | Redis (internal)     | Shared   |

### Port Allocation Rules

1. **Never hardcode ports in templates** — always pass via `--port` flag
2. **Check before assigning**: `lsof -i :<port>` to verify availability
3. **Document immediately** — add to this table when assigning a new port
4. **Reserve ranges**:
   - `8000–8099`: Web applications
   - `8100–8199`: API services
   - `9000–9099`: Infrastructure/monitoring tools
   - `9100–9199`: Internal utilities

---

## Shared Services

### PostgreSQL (Shared Instance)

Run a single PostgreSQL instance and create per-project databases:

```yaml
# /opt/stacks/postgres/docker-compose.yml
services:
  postgres:
    image: postgres:16
    container_name: hawk-postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-net
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 5s
      retries: 3
```

**Create per-project databases:**

```bash
# Connect to shared Postgres
docker exec -it hawk-postgres psql -U postgres

# Create database and user for a project
CREATE DATABASE my_web_app;
CREATE USER my_web_app WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE my_web_app TO my_web_app;
```

**In project compose files, reference by container name:**

```yaml
environment:
  - DATABASE_URL=postgresql://my_web_app:secure_password@hawk-postgres:5432/my_web_app
```

### Redis (Shared Instance)

```yaml
# /opt/stacks/redis/docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    container_name: hawk-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - app-net
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3
```

**In project compose files:**

```yaml
environment:
  - REDIS_URL=redis://hawk-redis:6379/0
```

Use different Redis database numbers (0–15) per project to avoid key collisions.

---

## Backup Strategy

Each project has its own backup script in `.hermes/scripts/backup.sh`. A shared cron job orchestrates all backups.

### Per-Project Backup Script

```bash
# /opt/stacks/my-web-app/.hermes/scripts/backup.sh
#!/usr/bin/env bash
set -euo pipefail

PROJECT="my-web-app"
BACKUP_DIR="/Users/huoke/backups/${PROJECT}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup Docker volumes
docker run --rm \
  -v ${PROJECT}-data:/source:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/data_${TIMESTAMP}.tar.gz -C /source .

# Backup database (if applicable)
docker exec hawk-postgres pg_dump -U my_web_app my_web_app \
  > "${BACKUP_DIR}/pg_${TIMESTAMP}.sql"

# Keep only last 7 backups
ls -t ${BACKUP_DIR}/data_*.tar.gz | tail -n +8 | xargs rm -f 2>/dev/null
ls -t ${BACKUP_DIR}/pg_*.sql | tail -n +8 | xargs rm -f 2>/dev/null

echo "Backup complete: ${BACKUP_DIR}"
```

### Global Backup Orchestration

```bash
# /opt/stacks/_shared/backup-all.sh
#!/usr/bin/env bash
set -euo pipefail

for stack in /opt/stacks/*/; do
  backup_script="${stack}.hermes/scripts/backup.sh"
  if [ -f "$backup_script" ]; then
    echo "=== Backing up $(basename $stack) ==="
    bash "$backup_script" || echo "WARNING: backup failed for $(basename $stack)"
  fi
done
```

### Backup Schedule

| Data              | Frequency | Retention | Method                    |
|-------------------|-----------|-----------|---------------------------|
| Docker volumes    | Daily 3am | 7 days    | `tar` via alpine container|
| PostgreSQL        | Daily 3am | 7 days    | `pg_dump`                 |
| Redis             | Daily 3am | 7 days    | `redis-cli BGSAVE` + copy |
| Config files      | On deploy | Git history| Git commit                |

---

## Deployment Order

Shared services **must** be deployed before application services. This ensures databases and caches are available when apps start.

### Correct Order

```
1. Shared infrastructure
   ├── hawk-postgres        (database)
   ├── hawk-redis           (cache)
   ├── hawk-cloudflared     (tunnel)
   └── hawk-transmission    (PT, always-on)

2. Application services (any order)
   ├── hawk-my-web-app
   ├── hawk-my-api
   └── hawk-monitoring
```

### Deploy Script for All Services

```bash
# /opt/stacks/_shared/deploy-all.sh
#!/usr/bin/env bash
set -euo pipefail

export DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock

# Phase 1: Shared services
SHARED_SERVICES=("postgres" "redis" "cloudflared" "transmission")
for svc in "${SHARED_SERVICES[@]}"; do
  stack="/opt/stacks/${svc}"
  if [ -f "${stack}/docker-compose.yml" ]; then
    echo "=== Starting ${svc} ==="
    (cd "$stack" && docker compose up -d)
    sleep 5
  fi
done

# Phase 2: Application services
for stack in /opt/stacks/*/; do
  name=$(basename "$stack")
  # Skip shared services (already started) and special dirs
  if [[ " ${SHARED_SERVICES[*]} " =~ " ${name} " ]] || [[ "$name" == "_shared" ]]; then
    continue
  fi
  if [ -f "${stack}/docker-compose.yml" ]; then
    echo "=== Starting ${name} ==="
    (cd "$stack" && docker compose up -d --no-deps)
  fi
done

echo "=== All services started ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Single-Project Deploy (Safe)

```bash
# Always use --no-deps to avoid affecting other services
cd /opt/stacks/my-web-app
export DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock
docker compose up -d --no-deps --force-recreate my-web-app
```

---

## Adding a New Project

1. **Choose a port** — check availability, update the port table above
2. **Scaffold the project**:
   ```bash
   cd /opt/stacks
   bash /path/to/hawk-homelab-methodology/cli/shell/init.sh my-new-app \
     --port 8081 --image node --version 18 --description "My new service"
   ```
3. **Create shared resources** (database, redis DB) if needed
4. **Deploy**: `cd my-new-app && bash deploy.sh`
5. **Verify**: `curl -f http://localhost:8081/health`
6. **Update documentation**: add port to allocation table, update this guide
