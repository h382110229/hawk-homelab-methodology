#!/usr/bin/env bash
# pre-deploy-check.sh — 部署前安全检查
# 检查: 磁盘 / 内存 / Colima / Transmission / Clash / Cloudflare
set -euo pipefail

DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
export DOCKER_HOST

# ============================================================
# 颜色
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

check_pass() { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS + 1)); }
check_warn() { echo -e "  ${YELLOW}⚠${NC} $*"; WARN=$((WARN + 1)); }
check_fail() { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL + 1)); }

# ============================================================
# 检查项
# ============================================================

check_disk() {
    echo "📦 Disk Space"
    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    local avail
    avail=$(df -h / | awk 'NR==2 {print $4}')

    if [ "$usage" -lt 80 ]; then
        check_pass "Disk usage: ${usage}% (available: $avail)"
    elif [ "$usage" -lt 90 ]; then
        check_warn "Disk usage: ${usage}% (available: $avail) — getting low"
    else
        check_fail "Disk usage: ${usage}% (available: $avail) — critically low!"
    fi
}

check_memory() {
    echo "🧠 Memory"
    local total
    total=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024)}')
    local free_pages
    free_pages=$(vm_stat | awk '/Pages free/ {gsub(/\./,"",$3); print $3}' 2>/dev/null || echo "0")
    local page_size
    page_size=$(vm_stat | awk '/page size/ {print $NF}' 2>/dev/null || echo "4096")
    local free_mb=$(( (free_pages * page_size) / 1024 / 1024 ))

    if [ "$free_mb" -gt 2048 ]; then
        check_pass "Free memory: ${free_mb}MB / ${total}GB"
    elif [ "$free_mb" -gt 1024 ]; then
        check_warn "Free memory: ${free_mb}MB / ${total}GB — may be tight"
    else
        check_fail "Free memory: ${free_mb}MB / ${total}GB — very low!"
    fi
}

check_colima() {
    echo "🐳 Colima / Docker"

    # 检查 Colima 进程
    if pgrep -x colima > /dev/null 2>&1; then
        check_pass "Colima process running"
    else
        check_fail "Colima is not running! Start with: colima start"
        return
    fi

    # 检查 Docker socket
    if [ -S "${DOCKER_HOST#unix://}" ]; then
        check_pass "Docker socket exists: $DOCKER_HOST"
    else
        check_fail "Docker socket not found: $DOCKER_HOST"
        return
    fi

    # 检查 Docker daemon
    if docker info > /dev/null 2>&1; then
        check_pass "Docker daemon responsive"
    else
        check_fail "Docker daemon not responding"
    fi
}

check_transmission() {
    echo "📥 Transmission (PT Protection)"

    local containers
    containers=$(docker ps --format '{{.Names}}' 2>/dev/null)

    if echo "$containers" | grep -q "hawk-transmission"; then
        check_pass "Transmission container running"
    else
        check_warn "Transmission container not found — is it deployed?"
    fi
}

check_clash() {
    echo "🌐 Clash Verge"

    # 检查 TUN 模式 (通过检查 utun 接口)
    if ifconfig 2>/dev/null | grep -q "utun"; then
        check_pass "TUN interface active"
    else
        check_warn "TUN interface not detected — Clash TUN may be off"
    fi

    # 检查 DNS 解析
    if nslookup google.com > /dev/null 2>&1; then
        check_pass "DNS resolution working"
    else
        check_warn "DNS resolution may have issues"
    fi
}

check_cloudflare() {
    echo "☁️  Cloudflare Tunnel"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "hawk-cloudflared"; then
        check_pass "Cloudflare tunnel container running"
    else
        check_warn "Cloudflare tunnel container not found"
    fi
}

check_network() {
    echo "🔗 Docker Network"

    if docker network inspect app-net > /dev/null 2>&1; then
        check_pass "app-net network exists"
    else
        check_warn "app-net network not found — will be created on deploy"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo "============================================"
    echo " Pre-deploy Check — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================"
    echo ""

    check_disk
    echo ""
    check_memory
    echo ""
    check_colima
    echo ""
    check_transmission
    echo ""
    check_clash
    echo ""
    check_cloudflare
    echo ""
    check_network

    echo ""
    echo "============================================"
    echo " Results: ${GREEN}${PASS} passed${NC}  ${YELLOW}${WARN} warnings${NC}  ${RED}${FAIL} failures${NC}"
    echo "============================================"

    if [ $FAIL -gt 0 ]; then
        echo -e "${RED}Deploy NOT safe — fix failures first!${NC}"
        exit 1
    elif [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}Deploy possible but review warnings${NC}"
        exit 0
    else
        echo -e "${GREEN}All checks passed — ready to deploy ✓${NC}"
        exit 0
    fi
}

main
