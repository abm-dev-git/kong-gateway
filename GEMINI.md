# Kong Gateway — ABM.dev API Gateway

This repository contains the Kong OSS 3.5 configuration for the ABM.dev platform, serving as the single entry point for all customer-facing API traffic.

## Project Overview

- **Core Technology:** Kong Gateway OSS 3.5.
- **Configuration Mode:**
    - **Local Development:** Postgres-backed mode for dynamic updates via Admin API.
    - **Production (Railway):** DB-less mode using declarative configuration (`kong.yml`).
- **Primary Responsibility:** Routing, Authentication (JWT/API Key), Rate Limiting, and CORS.
- **Upstream:** Primarily routes to the `abmdev-backend` (abm.dev-platform).

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

## Building & Running

### Local Development

Local development uses Docker Compose with PostgreSQL and Redis.

1.  **Initialize:**
    ```bash
    cp .env.example .env
    ./scripts/bootstrap.sh
    ```
2.  **Start Services:**
    ```bash
    docker compose up -d
    ```
3.  **Ports:**
    - **Proxy:** `http://localhost:8080`
    - **Admin API:** `http://localhost:8081` (127.0.0.1 only)
    - **Postgres:** `localhost:5434`
    - **Redis:** `localhost:6380`

### Production (Railway)

The production environment runs in DB-less mode.

- **Deployment:** Every push to `production` branch triggers a Railway redeploy.
- **Config:** `kong.yml` is the source of truth, baked into the image.
- **Startup:** The `Dockerfile` uses a custom `start-kong.sh` which runs `kong start` and then `setup-jwt.sh` to sync Clerk credentials.

### Health Verification

Run the health check script to verify services:
```bash
./scripts/health-check.sh
```

## Development Conventions

### Declarative Configuration (`kong.yml`)

All services, routes, and plugins are defined in `kong.yml`.
- **Services:** Group routes by upstream destination.
- **Routes:** Define paths, methods, and tags.
- **Plugins:** Configured globally or per-route/service (e.g., `rate-limiting`, `jwt`, `key-auth`).

### Adding a New Route

1.  Edit `kong.yml` and add the route under the appropriate service.
2.  **Validate:** `docker exec kong kong config parse /etc/kong/kong.yml`.
3.  **Reload (Local):** `docker exec kong kong config db_import /etc/kong/kong.yml` (Note: UNIQUE violations may occur; a restart is cleaner).
4.  **Deploy (Prod):** Commit and push to `production`.

### Authentication Flows

Kong supports two primary authentication methods:

1.  **JWT Authentication (Clerk):**
    - Consumer: `clerk-jwt`
    - `setup-jwt.sh` fetches the latest JWKS from Clerk and configures the `jwt` plugin.
    - Used by the portal/frontend.
2.  **API Key Authentication:**
    - Uses `x-api-key` header.
    - Consumers are created in `kong.yml` with their respective keys.
    - Used for programmatic access.

### Rate Limiting

- **Policy:** `local` in production (in-memory per replica), `redis` in local dev.
- **Tags:** Use `rate-limit-standard` (100/min) or `rate-limit-enrichment` (20/min) to apply predefined limits.

## Key Commands

| Task | Command |
|------|---------|
| Start All | `docker compose up -d` |
| View Logs | `docker compose logs -f kong` |
| Health Check | `./scripts/health-check.sh` |
| Validate Config | `docker exec kong kong config parse /etc/kong/kong.yml` |
| Import Config (Local) | `docker exec kong kong config db_import /etc/kong/kong.yml` |
| Setup JWT | `./setup-jwt.sh` |

## TODOs & Inferred Items

- [ ] **Redis in Prod:** Currently disabled in `Dockerfile`. Enable once Redis service is stable on Railway.
- [ ] **PostHog Plugin:** Not currently baked into the Dockerfile. Needs `luarocks install kong-plugin-posthog`.
- [ ] **Admin API Security:** Ensure Admin API is never exposed publicly (currently bound to `127.0.0.1` in compose, `0.0.0.0` in Dockerfile but protected by Railway firewall).
- [ ] **Certificates:** Local TLS uses self-signed certs in `ssl/`.
