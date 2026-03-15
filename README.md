# Echogram

Echogram is a Telegram-native bot framework with a local-first web control surface.

## Layout

- `backend/`: local HTTP API for Echogram Web
- `core/`: Telegram bot runtime and orchestration
- `apps/echogram_web/`: Jaspr frontend
- `packages/echogram_core/`: shared Dart models and API client

## Local Development

1. Copy `.env.example` to `.env`.
2. Fill in `TG_BOT_TOKEN` and `ADMIN_USER_ID`.
3. Start the bot:
   - `python main.py`
4. Start Echogram Web:
   - `cd apps/echogram_web`
   - `npm install`
   - `dart pub get`
   - `npm run watch:css`
   - `jaspr serve`

## Docker Compose

The root `docker-compose.yml` is deployment-oriented and pulls prebuilt images instead of building on the target machine.

1. Copy `.env.example` to `.env`.
2. Fill in `TG_BOT_TOKEN` and `ADMIN_USER_ID`.
3. Pull images:
   - `docker compose pull`
4. Start services:
   - `docker compose up -d`

Default addresses:

- Home: `http://localhost:8080/`
- Dashboard: `http://localhost:8080/dashboard`

For local Docker builds during development, use the override file:

- `docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build`

## GitHub Container Registry

The repository includes `.github/workflows/publish-images.yml`, which builds and pushes:

- `ghcr.io/Kanscape/echogram-backend`
- `ghcr.io/Kanscape/echogram-web`

The workflow runs on pushes to `main`, version tags like `v1.0.0`, and manual dispatch.
