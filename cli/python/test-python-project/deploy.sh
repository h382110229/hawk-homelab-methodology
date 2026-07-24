#!/usr/bin/env bash
# deploy.sh — test-python-project 部署脚本
# Colima 感知 · Clash 检查 · PT 保护 · 健康检查 · 自动回滚
set -euo pipefail

# ============================================================
# 配置
# ============================================================
PROJECT_NAME="test-python-project"
COMPOSE_FILE="docker-compose.yml"
HEALTH_URL="http://localhost:5555/health"
HEALTH_TIMEOUT=120
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
NOTIFY_SCRIPT=".hermes/scripts/notify.sh"

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
# 前置检查
# ============================================================
preflight() {
    log_info "Running pre-deploy checks..."

    # 检查 Docker socket
    if [ ! -S "${DOCKER_HOST#unix://}" ]; then
        log_error "Docker socket not found: $DOCKER_HOST"
        log_error "Is Colima running? Run: colima status"
        exit 1
    fi

    # 检查 compose 文件
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.yml not found"
        exit 1
    fi

    # 验证 compose 文件
    docker compose config --quiet || {
        log_error "Invalid docker-compose.yml"
        exit 1
    }

    # 检查 Transmission
    if docker ps --format '{{.Names}}' | grep -q "hawk-transmission"; then
        log_info "Transmission is running ✓"
    else
        log_warn "Transmission container not found — PT downloads may be affected"
    fi

    # 运行 pre-deploy-check.sh
    if [ -f "pre-deploy-check.sh" ]; then
        bash pre-deploy-check.sh || {
            log_error "Pre-deploy check failed"
            exit 1
        }
    fi
}

# ============================================================
# 记录当前版本（用于回滚）
# ============================================================
save_rollback_state() {
    local image
    image=$(docker compose ps --format json "$PROJECT_NAME" 2>/dev/null | \
            python3 -c "import sys,json; print(json.load(sys.stdin).get('Image',''))" 2>/dev/null || echo "")
    echo "$image" > ".rollback_image"
    log_info "Saved rollback state: ${image:-<first deploy>}"
}

# ============================================================
# 部署
# ============================================================
deploy() {
    log_info "Deploying $PROJECT_NAME..."

    # 拉取新镜像
    log_info "Pulling images..."
    docker compose pull "$PROJECT_NAME"

    # 只重启目标服务，不影响其他容器（PT 保护）
    log_info "Starting service (no-deps)..."
    docker compose up -d --no-deps --force-recreate "$PROJECT_NAME"

    log_info "Service started, waiting for health check..."
}

# ============================================================
# 健康检查
# ============================================================
wait_healthy() {
    local elapsed=0
    local interval=5

    while [ $elapsed -lt $HEALTH_TIMEOUT ]; do
        if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
            log_info "Health check passed ✓ (${elapsed}s)"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done

    echo ""
    log_error "Health check failed after ${HEALTH_TIMEOUT}s"
    return 1
}

# ============================================================
# 回滚
# ============================================================
rollback() {
    log_warn "Rolling back $PROJECT_NAME..."

    if [ -f ".rollback_image" ]; then
        local prev_image
        prev_image=$(cat .rollback_image)
        if [ -n "$prev_image" ]; then
            log_info "Rolling back to: $prev_image"
            # 更新 compose 文件中的镜像版本
            docker compose pull "$PROJECT_NAME" 2>/dev/null || true
            docker compose up -d --no-deps --force-recreate "$PROJECT_NAME" 2>/dev/null || true
        fi
    fi

    # 尝试 git 回滚
    if git rev-parse HEAD~1 > /dev/null 2>&1; then
        log_info "Git rollback to previous commit..."
        git checkout -- docker-compose.yml 2>/dev/null || true
        docker compose up -d --no-deps --force-recreate "$PROJECT_NAME"
    fi

    rm -f .rollback_image
}

# ============================================================
# 通知
# ============================================================
notify() {
    local status="$1"
    local message="$2"

    if [ -f "$NOTIFY_SCRIPT" ]; then
        bash "$NOTIFY_SCRIPT" "$status" "$message" 2>/dev/null || true
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    log_info "=== Deploying $PROJECT_NAME ==="
    log_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"

    preflight
    save_rollback_state

    if deploy && wait_healthy; then
        log_info "=== Deployment successful ✓ ==="
        notify "success" "$PROJECT_NAME deployed successfully"
        rm -f .rollback_image
    else
        log_error "=== Deployment failed, rolling back... ==="
        rollback
        notify "failure" "$PROJECT_NAME deployment failed, rolled back"
        exit 1
    fi
}

main "$@"
