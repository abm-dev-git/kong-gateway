# Kong Gateway - ABM.dev API Gateway

Kong Gateway OSS 3.5 configuration for the ABM.dev platform, replacing Zuplo as the API gateway.

## Overview

This repository contains the Kong Gateway configuration for routing, authentication, and rate limiting for the ABM.dev API platform.

**Related Resources:**
- [Epic #1: Kong Gateway Infrastructure](https://github.com/abm-dev-git/kong-gateway/issues/1)
- [GitHub Project](https://github.com/orgs/abm-dev-git/projects/3)
- Backend API: [abm.dev-platform](../abm.dev-platform)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PUBLIC INTERNET                              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Kong Gateway (8080)  │
                    │                       │
                    │  Plugins:             │
                    │  - JWT validation     │
                    │  - Key-Auth           │
                    │  - Rate-Limiting      │
                    │  - Correlation-ID     │
                    │  - Request-Transform  │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Backend API (8000)   │
                    │  (abm.dev-platform)   │
                    └───────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- [abm.dev-platform](../abm.dev-platform) running (for backend API)

### Setup

1. **Clone and configure:**
   ```bash
   cd kong-gateway
   cp .env.example .env
   # Edit .env with your Clerk credentials
   ```

2. **Start services:**
   ```bash
   ./scripts/bootstrap.sh
   ```

3. **Verify health:**
   ```bash
   ./scripts/health-check.sh
   ```

### Manual Start

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f kong

# Stop services
docker compose down
```

## Services & Ports

| Service | Internal Port | External Port | Description |
|---------|---------------|---------------|-------------|
| kong | 8000 | 8080 | API Proxy |
| kong-admin | 8001 | 8081 | Admin API |
| kong-db | 5432 | 5434 | PostgreSQL |
| redis | 6379 | 6380 | Rate limiting |

## Routes

Kong routes requests to the ABM.dev backend API:

| Kong Path | Backend Path | Auth Required | Rate Limit |
|-----------|--------------|---------------|------------|
| `/health` | `/health` | No | None |
| `/v1/enrichment/*` | `/api/v1/enrichment/*` | Yes | 20/min |
| `/v1/linkedin-connection/*` | `/api/v1/linkedin-connection/*` | Yes | 100/min |
| `/v1/hubspot/*` | `/api/v1/hubspot/*` | Yes | 100/min |
| `/v1/api-keys/*` | `/api/v1/ApiKeys/*` | Yes | 100/min |
| `/v1/organizations/*` | `/api/v1/organizations/*` | Yes | 100/min |
| `/v1/status/*` | `/api/v1/status/*` | Yes | None |
| `/webhooks/clerk` | `/webhooks/clerk` | No | None |

## Authentication

Kong supports **either** JWT Bearer tokens **or** API keys (x-api-key header):

### JWT Authentication (Clerk)
```bash
curl -H "Authorization: Bearer $CLERK_TOKEN" http://localhost:8080/v1/status
```

### API Key Authentication
```bash
curl -H "x-api-key: abmdev_live_xxx" http://localhost:8080/v1/status
```

## Configuration Files

| File | Description |
|------|-------------|
| `kong.yml` | Declarative routes and plugins configuration |
| `docker-compose.yml` | Local development services |
| `docker-compose.prod.yml` | Production overlay |
| `.env.example` | Environment variables template |

## Development

### View Kong Configuration
```bash
curl http://localhost:8081/services | jq
curl http://localhost:8081/routes | jq
curl http://localhost:8081/plugins | jq
```

### Test Rate Limiting
```bash
# Should fail after 20 requests/minute for enrichment routes
for i in {1..25}; do
  curl -H "x-api-key: test" http://localhost:8080/v1/enrichment/entities
done
```

### Reload Configuration
```bash
# Sync kong.yml to running Kong instance
docker compose exec kong kong config db_import /etc/kong/kong.yml
```

## Troubleshooting

### Kong not starting
```bash
# Check logs
docker compose logs kong

# Verify database connection
docker compose exec kong kong health
```

### Routes not working
```bash
# List all routes
curl http://localhost:8081/routes | jq

# Check specific route
curl http://localhost:8081/routes/route-name | jq
```

## License

Private - ABM.dev
