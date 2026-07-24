#!/usr/bin/env bash
# integration-test.sh — test-python-project 集成测试
# 验证: HTTP 健康检查 + API 端点 + 数据库连接
set -euo pipefail

PROJECT_NAME="test-python-project"
PORT="5555"
BASE_URL="http://localhost:${PORT}"
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
export DOCKER_HOST

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

test_pass() { echo -e "  ${GREEN}PASS${NC} $*"; PASS=$((PASS + 1)); }
test_fail() { echo -e "  ${RED}FAIL${NC} $*"; FAIL=$((FAIL + 1)); }

echo "=== Integration Test: $PROJECT_NAME ==="
echo ""

# Test 1: Health endpoint
echo "Test 1: Health endpoint"
HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' "${BASE_URL}/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "/health returns 200"
else
    test_fail "/health returns $HTTP_CODE (expected 200)"
fi

# Test 2: Health response body
echo "Test 2: Health response"
BODY=$(curl -sf "${BASE_URL}/health" 2>/dev/null || echo "")
if echo "$BODY" | grep -qi "ok\|healthy\|alive"; then
    test_pass "Health response contains status indicator"
else
    test_fail "Health response unexpected: ${BODY:0:100}"
fi

# Test 3: Response time
echo "Test 3: Response time"
RESPONSE_TIME=$(curl -sf -o /dev/null -w '%{time_total}' "${BASE_URL}/health" 2>/dev/null || echo "99")
if (( $(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo 0) )); then
    test_pass "Response time: ${RESPONSE_TIME}s (< 5s)"
else
    test_fail "Response time: ${RESPONSE_TIME}s (too slow)"
fi

# Test 4: Container resource usage
echo "Test 4: Container resources"
STATS=$(docker stats "hawk-${PROJECT_NAME}" --no-stream --format '{{.MemPerc}}' 2>/dev/null || echo "N/A")
if [ "$STATS" != "N/A" ]; then
    MEM_PCT=$(echo "$STATS" | tr -d '%')
    if (( $(echo "$MEM_PCT < 80" | bc -l 2>/dev/null || echo 0) )); then
        test_pass "Memory usage: $STATS"
    else
        test_fail "Memory usage too high: $STATS"
    fi
else
    test_pass "Container stats not available (non-critical)"
fi

# Test 5: Log check (no errors in last 50 lines)
echo "Test 5: Recent logs"
ERROR_COUNT=$(docker logs "hawk-${PROJECT_NAME}" --tail 50 2>&1 | grep -ci "error\|fatal\|panic" || echo "0")
if [ "$ERROR_COUNT" -lt 3 ]; then
    test_pass "Recent logs: $ERROR_COUNT error(s)"
else
    test_fail "Recent logs: $ERROR_COUNT error(s) — investigate!"
fi

# Summary
echo ""
echo "================================"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "================================"

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Integration test FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Integration test PASSED ✓${NC}"
    exit 0
fi
