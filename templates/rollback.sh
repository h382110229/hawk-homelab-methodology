#!/usr/bin/env bash
# rollback.sh — {{PROJECT_NAME}} 回滚脚本
# 4 级回滚: 服务级 → Git 级 → 数据库级 → Colima 级
set -euo pipefail

# ============================================================
# 配置
# ============================================================
PROJECT_NAME="{{PROJECT_NAME}}"
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
DB_CONTAINER="hawk-postgres"
DB_USER="{{DB_USER}}"
export DOCKER_HOST

# ============================================================
# 颜色
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================
# 用法
# ============================================================
usage() {
    cat <<EOF
Usage: $0 <level>

Rollback levels:
  service    Rollback service to previous image version (Level 1)
  git        Revert last git commit and redeploy (Level 2)
  pg         Restore PostgreSQL from latest backup (Level 3)
  colima     Restart Colima — LAST RESORT, interrupts ALL services (Level 4)

Examples:
  $0 service          # Quick rollback, only affects $PROJECT_NAME
  $0 git              # Code rollback
  $0 pg               # Database rollback (requires backup)
  $0 colima           # Nuclear option — stops Transmission!
EOF
    exit 1
}

# ============================================================
# Level 1: 服务级回滚
# ============================================================
rollback_service() {
    log_info "=== Level 1: Service Rollback ==="
    # PT 保护: 确认不会影响 Transmission
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "hawk-transmission"; then
        log_info "Transmission running — will NOT be affected by this rollback"
    fi
    log_info "Rolling back $PROJECT_NAME to previous version..."

    # 检查是否有保存的回滚镜像
    if [ -f ".rollback_image" ]; then
        local prev_image
        prev_image=$(cat .rollback_image)
        log_info "Previous image: $prev_image"
    fi

    # 重新拉取并启动
    docker compose pull "$PROJECT_NAME"
    docker compose up -d --no-deps --force-recreate "$PROJECT_NAME"

    # 等待健康检查
    sleep 10
    if curl -sf "http://localhost:{{PORT}}/health" > /dev/null 2>&1; then
        log_info "Service rollback successful ✓"
    else
        log_warn "Service rollback: health check not yet passing"
        log_warn "Try: docker compose logs $PROJECT_NAME"
    fi
}

# ============================================================
# Level 2: Git 级回滚
# ============================================================
rollback_git() {
    log_info "=== Level 2: Git Rollback ==="

    if ! git rev-parse HEAD~1 > /dev/null 2>&1; then
        log_error "No previous commit to revert to"
        exit 1
    fi

    local current_commit
    current_commit=$(git rev-parse --short HEAD)
    log_info "Current commit: $current_commit"
    log_info "Reverting to previous commit..."

    git revert HEAD --no-edit

    # 重新部署
    log_info "Redeploying from reverted commit..."
    docker compose pull "$PROJECT_NAME"
    docker compose up -d --no-deps --force-recreate "$PROJECT_NAME"

    sleep 10
    if curl -sf "http://localhost:{{PORT}}/health" > /dev/null 2>&1; then
        log_info "Git rollback + redeploy successful ✓"
    else
        log_error "Git rollback: health check failing"
        log_error "Manual intervention required"
        exit 1
    fi
}

# ============================================================
# Level 3: 数据库级回滚
# ============================================================
rollback_pg() {
    log_info "=== Level 3: PostgreSQL Rollback ==="
    log_warn "This will restore the database from backup!"
    log_warn "Current data WILL BE LOST."

    # 查找最新备份
    local backup_dir="backups"
    local latest_backup
    latest_backup=$(ls -t "$backup_dir"/pg_backup_*.sql 2>/dev/null | head -1)

    if [ -z "$latest_backup" ]; then
        log_error "No backup found in $backup_dir/"
        log_error "Cannot restore without a backup"
        exit 1
    fi

    log_info "Latest backup: $latest_backup"
    log_info "Backup size: $(du -h "$latest_backup" | cut -f1)"
    echo ""
    read -p "Are you sure? This will overwrite current database. (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Aborted"
        exit 0
    fi

    # 停止依赖数据库的服务
    log_info "Stopping $PROJECT_NAME..."
    docker compose stop "$PROJECT_NAME" 2>/dev/null || true

    # 恢复数据库
    log_info "Restoring database..."
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" < "$latest_backup"

    # 重启服务
    log_info "Restarting $PROJECT_NAME..."
    docker compose up -d --no-deps "$PROJECT_NAME"

    sleep 10
    if curl -sf "http://localhost:{{PORT}}/health" > /dev/null 2>&1; then
        log_info "Database rollback successful ✓"
    else
        log_error "Database rollback: health check failing"
        exit 1
    fi
}

# ============================================================
# Level 4: Colima 级回滚 (最后手段)
# ============================================================
rollback_colima() {
    log_error "=== Level 4: Colima Restart (NUCLEAR OPTION) ==="
    log_error "⚠️  THIS WILL STOP ALL CONTAINERS INCLUDING TRANSMISSION!"
    log_error "⚠️  PT downloads will be interrupted!"
    log_error "⚠️  This should only be used as a LAST RESORT!"
    echo ""
    read -p "Type 'NUCLEAR' to confirm: " confirm
    if [ "$confirm" != "NUCLEAR" ]; then
        log_info "Aborted"
        exit 0
    fi

    log_warn "Restarting Colima..."
    colima stop
    sleep 5
    colima start

    log_info "Waiting for Docker to be ready..."
    sleep 15
    until docker info > /dev/null 2>&1; do
        sleep 5
    done

    log_info "Restarting all containers..."
    # 重启 app-net 网络
    docker network create app-net 2>/dev/null || true

    # 重启所有 hawk-managed 容器
    for compose_dir in /opt/stacks/*/; do
        if [ -f "$compose_dir/docker-compose.yml" ]; then
            log_info "Restarting services in $compose_dir..."
            (cd "$compose_dir" && docker compose up -d)
        fi
    done

    log_warn "Colima restart complete"
    log_warn "Please verify Transmission is running:"
    log_warn "  docker ps | grep transmission"
}

# ============================================================
# 主流程
# ============================================================
LEVEL="${1:-}"

case "$LEVEL" in
    service)  rollback_service ;;
    git)      rollback_git ;;
    pg)       rollback_pg ;;
    colima)   rollback_colima ;;
    *)        usage ;;
esac
