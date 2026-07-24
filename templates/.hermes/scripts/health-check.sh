#!/usr/bin/env bash
# health-check.sh — {{PROJECT_NAME}} 服务健康检查
# 供 Hermes cron job 调用
set -euo pipefail

PROJECT_NAME="{{PROJECT_NAME}}"
HEALTH_URL="http://localhost:{{PORT}}/health"
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
NOTIFY_SCRIPT=".hermes/scripts/notify.sh"
MAX_RETRIES=3
RETRY_INTERVAL=10

export DOCKER_HOST

check_container() {
    local status
    status=$(docker inspect --format='{{.State.Status}}' "hawk-${PROJECT_NAME}" 2>/dev/null || echo "not_found")
    echo "$status"
}

check_health_endpoint() {
    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        if curl -sf --max-time 5 "$HEALTH_URL" > /dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [ $attempt -lt $MAX_RETRIES ]; then
            sleep $RETRY_INTERVAL
        fi
    done
    return 1
}

main() {
    local container_status
    container_status=$(check_container)

    if [ "$container_status" != "running" ]; then
        echo "❌ Container hawk-${PROJECT_NAME} is $container_status"
        if [ -f "$NOTIFY_SCRIPT" ]; then
            bash "$NOTIFY_SCRIPT" "critical" "hawk-${PROJECT_NAME} container is $container_status"
        fi
        exit 1
    fi

    if check_health_endpoint; then
        echo "✅ ${PROJECT_NAME} healthy"
        exit 0
    else
        echo "❌ ${PROJECT_NAME} health check failed after $MAX_RETRIES attempts"
        if [ -f "$NOTIFY_SCRIPT" ]; then
            bash "$NOTIFY_SCRIPT" "critical" "${PROJECT_NAME} health check failed"
        fi
        exit 1
    fi
}

main
