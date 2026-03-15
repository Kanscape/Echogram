# Echogram Web

Jaspr frontend for Echogram Web.

## Development

1. Run `dart pub get`.
2. Run `npm install`.
3. Run `npm run watch:css`.
4. Run `jaspr serve`.

Landing page:

- `http://localhost:8080/`

Dashboard with the local Python API:

- `http://localhost:8080/dashboard?api=http://127.0.0.1:8765/api`

The UI auto-detects browser language (`zh` / `en`).

Manual overrides:

- `http://localhost:8080/?lang=zh`
- `http://localhost:8080/dashboard?api=http://127.0.0.1:8765/api&lang=en`

## Docker Compose

With the root-level `docker-compose.yml`, Echogram Web is served by Nginx and proxies `/api` to the Python backend.
That compose file is now pull-first and expects prebuilt images from GHCR instead of building on the target machine.

1. Copy `.env.example` to `.env`.
2. Fill in `TG_BOT_TOKEN` and `ADMIN_USER_ID`.
3. Run `docker compose pull`.
4. Run `docker compose up -d`.

By default both published ports bind to `127.0.0.1`, so the dashboard and API are only reachable from the local machine unless you intentionally change `ECHOGRAM_WEB_BIND` or `ECHOGRAM_API_BIND`.

After startup:

- Home: `http://localhost:8080/`
- Dashboard: `http://localhost:8080/dashboard`

In the compose deployment, `?api=` is not required because the web container proxies `/api` to `echogram-backend`.

## Local Docker Build

If you still want a local-only Docker build for development, use the override file:

- `docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build`
