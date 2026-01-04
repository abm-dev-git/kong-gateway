#!/bin/bash
# Kong Gateway Health Check Script
# Verifies all services are running and healthy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8081}"
KONG_PROXY_URL="${KONG_PROXY_URL:-http://localhost:8080}"

echo "=== Kong Gateway Health Check ==="
echo ""

# Function to check service
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}

    printf "Checking %-20s ... " "$name"

    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}OK${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}FAILED${NC} (HTTP $response, expected $expected_status)"
        return 1
    fi
}

# Track failures
failures=0

# Check Kong Admin API
if ! check_service "Kong Admin API" "$KONG_ADMIN_URL/status"; then
    ((failures++))
fi

# Check Kong Proxy (root)
if ! check_service "Kong Proxy (root)" "$KONG_PROXY_URL/"; then
    # Root might return 404 if no route, that's OK
    check_service "Kong Proxy (root)" "$KONG_PROXY_URL/" "404" || ((failures++))
fi

# Check Kong Health endpoint (if configured)
check_service "Kong Proxy /health" "$KONG_PROXY_URL/health" || true

# Check Kong Admin status details
echo ""
echo "=== Kong Status Details ==="
kong_status=$(curl -s "$KONG_ADMIN_URL/status" 2>/dev/null)
if [ -n "$kong_status" ]; then
    echo "$kong_status" | python3 -m json.tool 2>/dev/null || echo "$kong_status"
else
    echo -e "${YELLOW}Unable to fetch Kong status${NC}"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ $failures -eq 0 ]; then
    echo -e "${GREEN}All services are healthy!${NC}"
    exit 0
else
    echo -e "${RED}$failures service(s) failed health check${NC}"
    exit 1
fi
