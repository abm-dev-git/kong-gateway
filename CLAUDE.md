# Kong Gateway — ABM.dev API Gateway

Kong OSS 3.5 declarative-config gateway. Single entry point for all ABM.dev customer-facing API traffic.

- Prod: `https://api.abm.dev` (Railway, DBless mode, Dockerfile + kong.yml)
- Local dev: `http://localhost:8080` (docker-compose, Postgres mode)

## Repo layout

- `kong.yml` — all routes, services, plugins, consumers, jwt_secrets (source of truth for prod)
- `Dockerfile` — prod image: Kong + startup script that runs `kong start` then `setup-jwt.sh`
- `railway.toml` — Railway deploy config (healthcheck on `/health`)
- `docker-compose.yml` — local dev (Postgres + Redis + Kong on host network)
- `setup-jwt.sh` — runtime refresh of JWT creds from Clerk JWKS (safety net; declarative already has the key baked in)
- `scripts/` — bootstrap + health-check helpers
- `ssl/` — self-signed certs for local TLS

## Local dev

```bash
cp .env.example .env   # edit KONG_PG_* if needed
docker compose up -d
curl http://localhost:8081/status                 # admin: database.reachable=true
curl http://localhost:8080/health                 # proxy: 200 (forwards to backend)
```

Ports: proxy 8080, admin 8081 (127.0.0.1-only), Postgres 5434, Redis 6380.

Reload kong.yml into running local Kong (Postgres mode): delete conflicting entities first, then `docker exec kong kong config db_import /etc/kong/kong.yml` — or just `docker compose down -v && docker compose up -d` for a clean slate.

## Production (Railway)

DBless: `KONG_DATABASE=off`, `KONG_DECLARATIVE_CONFIG=/usr/local/kong/declarative/kong.yml`. Every push to `production` triggers Railway redeploy which reloads the config from scratch — no DB state to worry about.

Upstream: `http://abm-api.railway.internal:8080` (private Railway network to abm-api service).

## JWT (Clerk prod)

`kong.yml` has the prod Clerk key baked in inline under `jwt_secrets`:
- `key: "https://clerk.abm.dev"` (matches Clerk JWT `iss` claim)
- `rsa_public_key:` — PEM from Clerk JWKS, kid `ins_36XBbvwAspqFqEPDfPQ85VOtySB`

If Clerk rotates the signing key, either:
1. Refetch JWKS, convert to PEM, paste into `kong.yml`, push `production`. The Node.js JWKS→PEM logic in `setup-jwt.sh` (lines 65–91) is the reference.
2. Let `setup-jwt.sh` pick it up at container boot (it fetches `https://clerk.abm.dev/.well-known/jwks.json` — requires `clerk.abm.dev` grey-clouded in Cloudflare so the origin responds).

## Rate limiting

`policy: local` (in-memory, per Kong replica). Acceptable for launch with a single Railway replica. Redis-backed policy is scaffolded in `docker-compose.yml` for local dev but disabled in prod Dockerfile until Redis service is provisioned on Railway.

## Adding a new route

1. Edit `kong.yml` — follow the pattern (service → paths → methods → plugins). Tag with `rate-limit-standard` or `rate-limit-enrichment`.
2. Validate: `docker exec kong kong config parse /etc/kong/kong.yml`.
3. Locally: delete and re-import or restart containers.
4. Prod: commit + push `production` branch. Railway auto-deploys.

## Known gotchas

- `setup-jwt.sh` fails silently if `clerk.abm.dev` is orange-clouded in Cloudflare (CF Error 1000). Declarative config in `kong.yml` is the fallback — always keep the prod key valid there.
- `kong-plugin-posthog` used to be runtime-installed on the old Kong instance. **Not baked into the current Dockerfile** — analytics via Kong is deferred. PostHog is still captured directly in the portal. Re-add to Dockerfile (`RUN luarocks install kong-plugin-posthog` + `KONG_PLUGINS=bundled,posthog`) when ready.
- Admin API listens only on `127.0.0.1:8001` (compose) / internal in prod — never expose publicly.
- `db_import` on a live Postgres-mode instance errors on UNIQUE violations; either purge the DB first or use Admin API PATCH calls for single entities.

## Sibling repos

- `abm.dev-platform` — backend services (abm-api, EntityEnrichment, etc.)
- `kong-portal` — Next.js frontend at `abm.dev`
- `abm-infrastructure` — Railway + DNS configs
