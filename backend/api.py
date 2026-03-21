import webbrowser
from typing import Any

from aiohttp import web

from config.settings import settings
from core.extensions import ExtensionInstallError
from utils.logger import logger

from .service import echogram_web_service

_runner: web.AppRunner | None = None
_site: web.TCPSite | None = None


def _cors_headers(request: web.Request) -> dict[str, str]:
    origin = request.headers.get("Origin")
    headers = {
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Echogram-Token",
        "Access-Control-Allow-Methods": "GET, PATCH, POST, OPTIONS",
    }
    headers["Access-Control-Allow-Origin"] = origin or "*"
    return headers


@web.middleware
async def cors_middleware(request: web.Request, handler):
    if request.method == "OPTIONS":
        response = web.Response(status=204)
    else:
        response = await handler(request)
    response.headers.update(_cors_headers(request))
    return response


@web.middleware
async def error_middleware(request: web.Request, handler):
    try:
        return await handler(request)
    except web.HTTPException:
        raise
    except Exception as exc:
        logger.error("Echogram Web API error: %s", exc, exc_info=True)
        return web.json_response({"error": str(exc)}, status=500)


@web.middleware
async def auth_middleware(request: web.Request, handler):
    expected = (settings.WEB_DASHBOARD_TOKEN or "").strip()
    if not expected:
        return await handler(request)

    provided = request.headers.get("X-Echogram-Token")
    if not provided and request.headers.get("Authorization", "").startswith("Bearer "):
        provided = request.headers["Authorization"][7:]
    if not provided:
        provided = request.query.get("token")

    if provided != expected:
        return web.json_response({"error": "unauthorized"}, status=401)

    return await handler(request)


def _parse_chat_id(request: web.Request) -> int:
    try:
        return int(request.match_info["chat_id"])
    except (KeyError, ValueError) as exc:
        raise web.HTTPBadRequest(reason="invalid chat id") from exc


def _parse_query_int(request: web.Request, key: str, default: int) -> int:
    value = request.query.get(key)
    if value is None or value == "":
        return default
    try:
        return int(value)
    except ValueError as exc:
        raise web.HTTPBadRequest(reason=f"invalid {key}") from exc


async def health(_request: web.Request) -> web.Response:
    return web.json_response({"ok": True, "name": "Echogram Web"})


async def meta(_request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.get_meta())


async def overview(_request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.get_overview())


async def get_settings(_request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.get_settings())


async def patch_settings(request: web.Request) -> web.Response:
    payload: Any = await request.json()
    if not isinstance(payload, dict):
        raise web.HTTPBadRequest(reason="settings payload must be an object")
    updated = await echogram_web_service.update_settings(payload)
    return web.json_response({"updated": updated})


async def chats(request: web.Request) -> web.Response:
    limit = request.query.get("limit")
    return web.json_response(await echogram_web_service.list_chats(limit=int(limit) if limit else 20))


async def chat_detail(request: web.Request) -> web.Response:
    detail = await echogram_web_service.get_chat_detail(
        _parse_chat_id(request),
        recent_limit=_parse_query_int(request, "recent_limit", 12),
    )
    if not detail:
        raise web.HTTPNotFound(reason="chat not found")
    return web.json_response(detail)


async def recent_messages(request: web.Request) -> web.Response:
    page = await echogram_web_service.get_recent_messages(
        _parse_chat_id(request),
        limit=_parse_query_int(request, "limit", 12),
        offset=_parse_query_int(request, "offset", 0),
    )
    if not page:
        raise web.HTTPNotFound(reason="chat not found")
    return web.json_response(page)


async def prompt_preview(request: web.Request) -> web.Response:
    preview = await echogram_web_service.build_prompt_preview(_parse_chat_id(request))
    if not preview:
        raise web.HTTPNotFound(reason="chat not found")
    return web.json_response(preview)


async def rag_records(request: web.Request) -> web.Response:
    page = await echogram_web_service.get_rag_records(
        _parse_chat_id(request),
        limit=_parse_query_int(request, "limit", 12),
        offset=_parse_query_int(request, "offset", 0),
    )
    if not page:
        raise web.HTTPNotFound(reason="chat not found")
    return web.json_response(page)


async def rebuild_rag(request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.rebuild_rag(_parse_chat_id(request)))


async def logs(request: web.Request) -> web.Response:
    char_limit = int(request.query.get("limit", "8000"))
    return web.json_response(await echogram_web_service.get_recent_logs(char_limit=char_limit))


async def subscriptions(_request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.get_subscriptions())


async def extensions(_request: web.Request) -> web.Response:
    return web.json_response(await echogram_web_service.get_extensions())


async def extension_detail(request: web.Request) -> web.Response:
    extension_id = (request.match_info.get("extension_id") or "").strip()
    detail = await echogram_web_service.get_extension_detail(extension_id)
    if not detail:
        raise web.HTTPNotFound(reason="extension not found")
    return web.json_response(detail)


async def enable_extension(request: web.Request) -> web.Response:
    extension_id = (request.match_info.get("extension_id") or "").strip()
    detail = await echogram_web_service.set_extension_enabled(extension_id, enabled=True)
    if not detail:
        raise web.HTTPNotFound(reason="extension not found")
    return web.json_response(detail)


async def disable_extension(request: web.Request) -> web.Response:
    extension_id = (request.match_info.get("extension_id") or "").strip()
    detail = await echogram_web_service.set_extension_enabled(extension_id, enabled=False)
    if not detail:
        raise web.HTTPNotFound(reason="extension not found")
    return web.json_response(detail)


async def patch_extension_config(request: web.Request) -> web.Response:
    extension_id = (request.match_info.get("extension_id") or "").strip()
    payload: Any = await request.json()
    if not isinstance(payload, dict):
        raise web.HTTPBadRequest(reason="config payload must be an object")
    try:
        detail = await echogram_web_service.update_extension_config(extension_id, payload)
    except ValueError as exc:
        raise web.HTTPBadRequest(reason=str(exc)) from exc
    if not detail:
        raise web.HTTPNotFound(reason="extension not found")
    return web.json_response(detail)


async def install_extension(request: web.Request) -> web.Response:
    try:
        if request.content_type.startswith("multipart/"):
            reader = await request.multipart()
            payload: dict[str, Any] = {}
            upload_filename: str | None = None
            upload_bytes: bytes | None = None

            async for part in reader:
                if part.name == "file":
                    upload_filename = part.filename
                    upload_bytes = await part.read()
                elif part.name:
                    payload[part.name] = await part.text()

            if upload_bytes is None:
                raise web.HTTPBadRequest(reason="missing file upload")

            result = await echogram_web_service.install_extension(
                payload,
                upload_filename=upload_filename,
                upload_bytes=upload_bytes,
            )
            return web.json_response(result)

        payload: Any = await request.json()
        if not isinstance(payload, dict):
            raise web.HTTPBadRequest(reason="install payload must be an object")
        result = await echogram_web_service.install_extension(payload)
        return web.json_response(result)
    except ExtensionInstallError as exc:
        raise web.HTTPBadRequest(reason=str(exc)) from exc


def create_app() -> web.Application:
    app = web.Application(middlewares=[cors_middleware, error_middleware, auth_middleware])
    app.router.add_get("/api/health", health)
    app.router.add_get("/api/meta", meta)
    app.router.add_get("/api/overview", overview)
    app.router.add_get("/api/settings", get_settings)
    app.router.add_patch("/api/settings", patch_settings)
    app.router.add_get("/api/chats", chats)
    app.router.add_get("/api/chats/{chat_id}", chat_detail)
    app.router.add_get("/api/chats/{chat_id}/messages", recent_messages)
    app.router.add_get("/api/chats/{chat_id}/prompt-preview", prompt_preview)
    app.router.add_get("/api/chats/{chat_id}/rag-records", rag_records)
    app.router.add_post("/api/chats/{chat_id}/rag/rebuild", rebuild_rag)
    app.router.add_get("/api/logs/recent", logs)
    app.router.add_get("/api/subscriptions", subscriptions)
    app.router.add_get("/api/extensions", extensions)
    app.router.add_get("/api/extensions/{extension_id}", extension_detail)
    app.router.add_post("/api/extensions/{extension_id}/enable", enable_extension)
    app.router.add_post("/api/extensions/{extension_id}/disable", disable_extension)
    app.router.add_patch("/api/extensions/{extension_id}/config", patch_extension_config)
    app.router.add_post("/api/extensions/install", install_extension)
    app.router.add_route("OPTIONS", "/{path_info:.*}", lambda _request: web.Response(status=204))
    return app


async def start_echogram_web_api() -> str | None:
    global _runner, _site

    if _runner is not None:
        return f"http://{settings.WEB_DASHBOARD_HOST}:{settings.WEB_DASHBOARD_PORT}/api"

    try:
        app = create_app()
        _runner = web.AppRunner(app)
        await _runner.setup()
        _site = web.TCPSite(_runner, settings.WEB_DASHBOARD_HOST, settings.WEB_DASHBOARD_PORT)
        await _site.start()
    except Exception as exc:
        logger.error("Failed to start Echogram Web API: %s", exc, exc_info=True)
        _runner = None
        _site = None
        return None

    api_url = f"http://{settings.WEB_DASHBOARD_HOST}:{settings.WEB_DASHBOARD_PORT}/api"
    logger.info("Echogram Web API listening at %s", api_url)

    if settings.WEB_DASHBOARD_AUTO_OPEN:
        target = settings.WEB_DASHBOARD_UI_URL or api_url
        try:
            webbrowser.open(target)
        except Exception as exc:
            logger.warning("Failed to open Echogram Web target %s: %s", target, exc)

    return api_url


async def stop_echogram_web_api():
    global _runner, _site

    if _runner is None:
        return

    try:
        await _runner.cleanup()
    finally:
        logger.info("Echogram Web API stopped.")
        _runner = None
        _site = None
