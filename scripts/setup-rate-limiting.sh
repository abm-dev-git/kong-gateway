#!/bin/bash
# Setup Rate Limiting for Kong Gateway Routes
#
# This script applies rate limiting to routes based on their tags:
#   - Routes with 'rate-limit-enrichment' tag: 20 req/min
#   - Routes with 'rate-limit-standard' tag: 100 req/min
#
# Prerequisites:
# - Kong Gateway running with Admin API accessible
# - Redis running for distributed rate limiting
# - jq installed for JSON parsing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8081}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

# Rate limit configurations
ENRICHMENT_LIMIT=20
STANDARD_LIMIT=100

echo "=== Kong Rate Limiting Setup ==="
echo ""
echo "Rate limits:"
echo "  - Enrichment routes: ${ENRICHMENT_LIMIT} req/min"
echo "  - Standard routes:   ${STANDARD_LIMIT} req/min"
echo "  - Redis:             ${REDIS_HOST}:${REDIS_PORT}"
echo ""

# Check prerequisites
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    exit 1
fi

# Check Kong Admin API
echo "1. Checking Kong Admin API..."
KONG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/status")

if [ "$KONG_STATUS" != "200" ]; then
    echo -e "${RED}Error: Kong Admin API not accessible (HTTP $KONG_STATUS)${NC}"
    exit 1
fi
echo -e "${GREEN}   Kong Admin API is accessible${NC}"

# Function to add rate limiting to a route
add_rate_limit() {
    local route_id=$1
    local route_name=$2
    local limit=$3

    # Check if rate-limiting already exists on this route
    existing=$(curl -s "$KONG_ADMIN_URL/routes/$route_id/plugins" | jq -r '.data[] | select(.name=="rate-limiting") | .id')

    if [ -n "$existing" ]; then
        echo -e "   ${YELLOW}Updating${NC} rate limit on $route_name"
        curl -s -X PATCH "$KONG_ADMIN_URL/plugins/$existing" \
            -d "config.minute=$limit" \
            -d "config.policy=redis" \
            -d "config.redis_host=$REDIS_HOST" \
            -d "config.redis_port=$REDIS_PORT" \
            -d "config.limit_by=header" \
            -d "config.header_name=x-org-id" > /dev/null
    else
        echo -e "   ${GREEN}Adding${NC} rate limit ($limit/min) to $route_name"
        curl -s -X POST "$KONG_ADMIN_URL/routes/$route_id/plugins" \
            -d "name=rate-limiting" \
            -d "config.minute=$limit" \
            -d "config.policy=redis" \
            -d "config.redis_host=$REDIS_HOST" \
            -d "config.redis_port=$REDIS_PORT" \
            -d "config.redis_timeout=2000" \
            -d "config.limit_by=header" \
            -d "config.header_name=x-org-id" \
            -d "config.hide_client_headers=false" \
            -d "config.fault_tolerant=true" > /dev/null
    fi
}

# Get all routes
echo ""
echo "2. Fetching routes..."
ROUTES=$(curl -s "$KONG_ADMIN_URL/routes" | jq -c '.data[]')

enrichment_count=0
standard_count=0
skipped_count=0

# Process routes with rate-limit-enrichment tag
echo ""
echo "3. Applying enrichment rate limits (${ENRICHMENT_LIMIT}/min)..."
echo "$ROUTES" | while read -r route; do
    route_id=$(echo "$route" | jq -r '.id')
    route_name=$(echo "$route" | jq -r '.name')
    tags=$(echo "$route" | jq -r '.tags // [] | join(",")')

    if echo "$tags" | grep -q "rate-limit-enrichment"; then
        add_rate_limit "$route_id" "$route_name" "$ENRICHMENT_LIMIT"
        ((enrichment_count++)) || true
    fi
done

# Process routes with rate-limit-standard tag
echo ""
echo "4. Applying standard rate limits (${STANDARD_LIMIT}/min)..."
echo "$ROUTES" | while read -r route; do
    route_id=$(echo "$route" | jq -r '.id')
    route_name=$(echo "$route" | jq -r '.name')
    tags=$(echo "$route" | jq -r '.tags // [] | join(",")')

    if echo "$tags" | grep -q "rate-limit-standard"; then
        add_rate_limit "$route_id" "$route_name" "$STANDARD_LIMIT"
        ((standard_count++)) || true
    fi
done

# Summary
echo ""
echo "=== Rate Limiting Setup Complete ==="
echo ""
echo "To verify, run:"
echo "  curl $KONG_ADMIN_URL/plugins | jq '.data[] | select(.name==\"rate-limiting\") | {route: .route.id, minute: .config.minute}'"
echo ""
echo "Test rate limiting:"
echo "  # Hit endpoint rapidly to trigger rate limit"
echo "  for i in {1..25}; do curl -H 'x-api-key: test' -H 'x-org-id: org_123' http://localhost:8080/v1/enrichment/entities -w '%{http_code}\n' -o /dev/null -s; done"
