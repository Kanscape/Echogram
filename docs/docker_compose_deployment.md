# Docker Compose Deployment

`docker-compose.yml` now packages Echogram as two services and is intended for pull-based deployment:

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
   - `ECHOGRAM_BACKEND_IMAGE`
   - `ECHOGRAM_WEB_IMAGE`
   - `ECHOGRAM_IMAGE_TAG`
5. Run `docker compose pull`.
6. Run `docker compose up -d`.

If the GHCR package is private, log in first:

- `echo <GHCR_PAT> | docker login ghcr.io -u <github-username> --password-stdin`

## Ports

- `ECHOGRAM_WEB_PORT` defaults to `8080` and publishes the browser UI.
- `ECHOGRAM_API_PORT` defaults to `8765` and is bound to `127.0.0.1` only for local debugging.
- `ECHOGRAM_WEB_BIND` defaults to `127.0.0.1`.
- `ECHOGRAM_API_BIND` defaults to `127.0.0.1`.
- `ECHOGRAM_IMAGE_TAG` defaults to `latest`.

## Cloudflare Tunnel

If you use Cloudflare Tunnel plus Cloudflare Access, this compose setup is a good fit:

- Keep both bind addresses on `127.0.0.1`.
- Point the tunnel origin at `http://localhost:8080`.
- Leave the backend API unpublished to the internet and let Nginx proxy `/api` internally.

With that setup, the dashboard is not directly exposed on a public interface, so ordinary internet port scans cannot hit it on your machine.

## Notes

- In local Jaspr development, keep using `?api=http://127.0.0.1:8765/api`.
- In compose deployment, the frontend automatically falls back to same-origin `/api`.
- If you want to build locally for development, use `docker-compose.local.yml` as an override instead of changing the deployment compose file.
