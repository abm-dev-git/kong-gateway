#!/bin/bash
# Create API Key Consumer and Key for Kong Gateway
#
# This script creates a consumer and API key for testing or production use.
#
# Usage:
#   ./scripts/create-api-key.sh <org_id> [key_name]
#
# Examples:
#   ./scripts/create-api-key.sh org_123456
#   ./scripts/create-api-key.sh org_123456 "Production Key"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8081}"

# Parse arguments
ORG_ID="${1:-}"
KEY_NAME="${2:-default}"

if [ -z "$ORG_ID" ]; then
    echo -e "${RED}Error: org_id is required${NC}"
    echo ""
    echo "Usage: $0 <org_id> [key_name]"
    echo ""
    echo "Examples:"
    echo "  $0 org_123456"
    echo "  $0 org_123456 'Production Key'"
    exit 1
fi

# Consumer username format
CONSUMER_USERNAME="org-${ORG_ID}"

echo "=== Create API Key Consumer ==="
echo ""
echo "Organization ID: $ORG_ID"
echo "Consumer:        $CONSUMER_USERNAME"
echo "Key Name:        $KEY_NAME"
echo ""

# Check Kong Admin API
echo "1. Checking Kong Admin API..."
KONG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/status")

if [ "$KONG_STATUS" != "200" ]; then
    echo -e "${RED}Error: Kong Admin API not accessible (HTTP $KONG_STATUS)${NC}"
    exit 1
fi
echo -e "${GREEN}   Kong Admin API is accessible${NC}"

# Check if consumer exists
echo ""
echo "2. Checking for existing consumer..."
CONSUMER_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/consumers/$CONSUMER_USERNAME")

if [ "$CONSUMER_EXISTS" = "200" ]; then
    echo -e "${YELLOW}   Consumer already exists${NC}"
else
    echo "   Creating consumer..."
    curl -s -X POST "$KONG_ADMIN_URL/consumers" \
        -d "username=$CONSUMER_USERNAME" \
        -d "custom_id=$ORG_ID" \
        -d "tags=org:$ORG_ID,api-key" > /dev/null
    echo -e "${GREEN}   Consumer created${NC}"
fi

# Generate API key
echo ""
echo "3. Generating API key..."

# Generate a random key in the format: abmdev_live_<random>
KEY_PREFIX="abmdev_live"
KEY_RANDOM=$(openssl rand -hex 16)
API_KEY="${KEY_PREFIX}_${KEY_RANDOM}"

# Create the key-auth credential
RESPONSE=$(curl -s -X POST "$KONG_ADMIN_URL/consumers/$CONSUMER_USERNAME/key-auth" \
    -d "key=$API_KEY" \
    -d "tags=$KEY_NAME")

KEY_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -z "$KEY_ID" ]; then
    echo -e "${RED}Error: Failed to create API key${NC}"
    echo "$RESPONSE" | jq .
    exit 1
fi

echo -e "${GREEN}   API key created${NC}"

echo ""
echo "=== API Key Created Successfully ==="
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ IMPORTANT: Save this key now. It cannot be retrieved later.│"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "API Key:    $API_KEY"
echo "Key ID:     $KEY_ID"
echo "Consumer:   $CONSUMER_USERNAME"
echo "Org ID:     $ORG_ID"
echo ""
echo "Test with:"
echo "  curl -H 'x-api-key: $API_KEY' http://localhost:8080/v1/status"
