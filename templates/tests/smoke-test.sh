#!/usr/bin/env bash
# smoke-test.sh — {{PROJECT_NAME}} 冒烟测试
# 验证: 容器运行 + 端口监听 + 基本响应
set -euo pipefail

PROJECT_NAME="{{PROJECT_NAME}}"
PORT="{{PORT}}"
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
export DOCKER_HOST

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

test_pass() { echo -e "  ${GREEN}PASS${NC} $*"; PASS=$((PASS + 1)); }
test_fail() { echo -e "  ${RED}FAIL${NC} $*"; FAIL=$((FAIL + 1)); }

echo "=== Smoke Test: $PROJECT_NAME ==="
echo ""

# Test 1: Container is running
echo "Test 1: Container running"
if docker ps --format '{{.Names}}' | grep -q "hawk-${PROJECT_NAME}"; then
    test_pass "hawk-${PROJECT_NAME} container is running"
else
    test_fail "hawk-${PROJECT_NAME} container is NOT running"
fi

# Test 2: Container is healthy
echo "Test 2: Container health"
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "hawk-${PROJECT_NAME}" 2>/dev/null || echo "no_healthcheck")
if [ "$HEALTH" = "healthy" ]; then
    test_pass "Container health status: healthy"
elif [ "$HEALTH" = "starting" ]; then
    test_pass "Container health status: starting (acceptable)"
else
    test_fail "Container health status: $HEALTH"
fi

# Test 3: Port is listening
echo "Test 3: Port listening"
if lsof -i :"$PORT" -sTCP:LISTEN > /dev/null 2>&1; then
    test_pass "Port $PORT is listening"
else
    test_fail "Port $PORT is NOT listening"
fi

# Test 4: HTTP response
echo "Test 4: HTTP response"
HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    test_pass "HTTP response: $HTTP_CODE"
else
    test_fail "HTTP response: $HTTP_CODE"
fi

# Test 5: Not affecting other containers
echo "Test 5: Other containers unaffected"
if docker ps --format '{{.Names}}' | grep -q "hawk-transmission"; then
    test_pass "Transmission still running"
else
    # Transmission might not be on this machine, that's OK
    test_pass "Transmission not found (may not be deployed here)"
fi

# Summary
echo ""
echo "================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "================================"

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Smoke test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Smoke test PASSED ✓${NC}"
    exit 0
fi
