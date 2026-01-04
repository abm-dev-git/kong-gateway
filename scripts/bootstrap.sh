#!/bin/bash
# Kong Gateway Bootstrap Script
# Runs database migrations and prepares Kong for first use

set -e

echo "=== Kong Gateway Bootstrap ==="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Warning: .env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "Please update .env with your configuration before running in production."
fi

# Source environment variables
source .env

echo "1. Starting PostgreSQL database..."
docker compose up -d kong-db
sleep 5

echo "2. Running Kong migrations..."
docker compose up kong-migrations

echo "3. Starting all services..."
docker compose up -d

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Kong Gateway is starting up. Services:"
echo "  - Kong Proxy:  http://localhost:${KONG_PROXY_PORT:-8080}"
echo "  - Kong Admin:  http://localhost:${KONG_ADMIN_PORT:-8081}"
echo "  - PostgreSQL:  localhost:5434"
echo "  - Redis:       localhost:6380"
echo ""
echo "Run './scripts/health-check.sh' to verify services are healthy."
