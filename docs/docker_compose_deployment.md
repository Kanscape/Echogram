# Docker Compose Deployment

`docker-compose.yml` now packages Echogram as two services:

- `echogram-backend`: the Telegram bot plus the local Echogram Web API
- `echogram-web`: the Jaspr build served by Nginx

## How It Works

- The backend listens on `0.0.0.0:8765` inside the compose network.
- The web container serves the built Jaspr app on port `80`.
- Nginx proxies `/api/*` to `http://echogram-backend:8765/api/*`.
- The browser can open `http://localhost:8080/dashboard` without adding `?api=...`.

## Start

1. Copy `.env.example` to `.env`.
2. Set `TG_BOT_TOKEN`.
3. Set `ADMIN_USER_ID`.
4. Optionally adjust:
   - `ECHOGRAM_WEB_PORT`
   - `ECHOGRAM_API_PORT`
   - `WEB_DASHBOARD_UI_URL`
   - `WEB_DASHBOARD_TOKEN`
5. Run `docker compose up -d --build`.

## Ports

- `ECHOGRAM_WEB_PORT` defaults to `8080` and publishes the browser UI.
- `ECHOGRAM_API_PORT` defaults to `8765` and is bound to `127.0.0.1` only for local debugging.

## Notes

- In local Jaspr development, keep using `?api=http://127.0.0.1:8765/api`.
- In compose deployment, the frontend automatically falls back to same-origin `/api`.
