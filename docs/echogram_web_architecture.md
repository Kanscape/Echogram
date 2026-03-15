# Echogram Web Architecture

## Goal

Move heavy operational surfaces out of Telegram and into a local browser dashboard while keeping in-chat shortcuts inside Telegram.

## Directory Layout

```text
backend/
  __init__.py
  api.py
  service.py

apps/
  echogram_web/
    lib/
    web/
    package.json

packages/
  echogram_core/
    lib/
```

## Responsibility Split

### Telegram

- Keep `/edit`, `/preview`, `/del`, and other fast chat-native actions.
- Keep direct moderation and short feedback loops inside the conversation.

### Echogram Web

- View recent runtime logs.
- Inspect prompt composition and active memory context.
- Audit RAG records and trigger RAG rebuilds.
- Watch subscription and distribution health.

### Shared Dart Core

- Typed API client for the local Python backend.
- View models and payload contracts shared by Jaspr now.
- Ready for reuse by a future Flutter client later.

## Why Jaspr + Flutter Works Long Term

### 1. One logic layer, multiple clients

Core models, API clients, and orchestration stay in pure Dart. Jaspr uses them now, and Flutter can reuse them later without duplicating backend contracts.

### 2. Web stays web-native

Jaspr renders real HTML and CSS. That makes Tailwind, DaisyUI, browser accessibility, DOM inspection, copy-heavy operational tables, and desktop browser workflows all feel natural.

### 3. Flutter stays product-ready

If Echogram eventually leaves Telegram and becomes a standalone desktop or mobile product, Flutter can become the primary client while reusing the same Dart core package.

### 4. Python remains the source of truth

Persistence, RAG state, log access, schedulers, and Telegram delivery stay in Python. The browser talks to a local HTTP API instead of reaching into bot internals.

## Local API Surface

The Python backend exposes a local API for Echogram Web:

- `GET /api/health`
- `GET /api/meta`
- `GET /api/overview`
- `GET /api/settings`
- `PATCH /api/settings`
- `GET /api/chats`
- `GET /api/chats/{chat_id}`
- `GET /api/chats/{chat_id}/prompt-preview`
- `GET /api/chats/{chat_id}/rag-records`
- `POST /api/chats/{chat_id}/rag/rebuild`
- `GET /api/logs/recent`
- `GET /api/subscriptions`

Optional auth is handled with `WEB_DASHBOARD_TOKEN`, passed as `X-Echogram-Token` or `?token=...`.

## Runbook

### Python side

Set these environment variables if needed:

```env
WEB_DASHBOARD_HOST=127.0.0.1
WEB_DASHBOARD_PORT=8765
WEB_DASHBOARD_UI_URL=
WEB_DASHBOARD_TOKEN=
WEB_DASHBOARD_AUTO_OPEN=false
```

Starting the bot also starts the local API.

### Jaspr side

```bash
cd apps/echogram_web
dart pub get
npm install
npm run watch:css
jaspr serve
```

Then open:

```text
http://localhost:8080/
```

For the operational dashboard:

```text
http://localhost:8080/dashboard?api=http://127.0.0.1:8765/api
```

If auth is enabled:

```text
http://localhost:8080/dashboard?api=http://127.0.0.1:8765/api&token=YOUR_TOKEN
```

Language defaults to browser/system preview. You can override it with:

```text
?lang=zh
?lang=en
```
