import os
import re
from datetime import datetime
from typing import Any

import pytz
from sqlalchemy import and_, desc, func, select

from config.database import get_db_session
from config.settings import settings
from core.config_service import config_service
from core.extensions import (
    ExtensionInstallError,
    extension_installer,
    extension_registry,
    extension_storage_service,
)
from core.history_service import history_service
from core.media_service import media_service
from core.news_push_service import news_push_service
from core.rag_service import rag_service
from core.summary_service import summary_service
from models.extension import ExtensionRecord, ExtensionSetting
from models.history import History
from models.news import ChatSubscription, NewsSubscription
from models.rag_status import RagStatus
from models.whitelist import Whitelist
from utils.logger import logger
from utils.prompts import prompt_builder


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _safe_int(value: Any, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _bounded(limit: int, default: int, maximum: int) -> int:
    return max(1, min(limit or default, maximum))


def _safe_offset(offset: int) -> int:
    return max(0, offset or 0)


def _clip(text: str, limit: int = 220) -> str:
    text = text or ""
    return text if len(text) <= limit else f"{text[: limit - 3]}..."


def _visible_content(raw_content: str) -> str:
    text = raw_content or ""
    match = re.search(r"<chat[^>]*>(?P<body>.*?)</chat>", text, flags=re.DOTALL | re.IGNORECASE)
    if match:
        return (match.group("body") or "").strip()
    return re.sub(r"<[^>]+>", "", text, flags=re.DOTALL).strip()


def _page(items: list[dict[str, Any]], total: int, limit: int, offset: int) -> dict[str, Any]:
    next_offset = offset + limit
    prev_offset = max(0, offset - limit)
    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_prev": offset > 0,
        "has_next": next_offset < total,
        "prev_offset": prev_offset if offset > 0 else None,
        "next_offset": next_offset if next_offset < total else None,
    }


async def _load_whitelist_map() -> dict[int, Whitelist]:
    async for session in get_db_session():
        result = await session.execute(select(Whitelist))
        items = result.scalars().all()
        return {item.chat_id: item for item in items}


def _extension_script_path(local_path: str) -> str:
    if not local_path:
        return ""
    return os.path.join(local_path, "extension.py")


def _record_preview(text: str, limit: int = 280) -> str:
    content = (text or "").strip()
    return content if len(content) <= limit else f"{content[: limit - 3]}..."


class EchogramWebService:
    async def _serialize_extension(self, manifest) -> dict[str, Any]:
        enabled = await extension_storage_service.get_extension_enabled(
            manifest.id,
            default=bool(manifest.enabled),
        )
        script_path = _extension_script_path(manifest.local_path)

        async for session in get_db_session():
            config_value_count = int(
                (
                    await session.execute(
                        select(func.count(ExtensionSetting.id)).where(
                            ExtensionSetting.extension_id == manifest.id,
                            ExtensionSetting.scope_type == "global",
                            ExtensionSetting.scope_id == 0,
                        )
                    )
                ).scalar_one()
                or 0
            )
            record_count = int(
                (
                    await session.execute(
                        select(func.count(ExtensionRecord.id)).where(
                            ExtensionRecord.extension_id == manifest.id,
                        )
                    )
                ).scalar_one()
                or 0
            )
            latest_record_at = (
                await session.execute(
                    select(func.max(ExtensionRecord.updated_at)).where(
                        ExtensionRecord.extension_id == manifest.id,
                    )
                )
            ).scalar_one_or_none()

        payload = manifest.to_dict()
        payload.update(
            {
                "enabled": enabled,
                "has_runtime": bool(script_path and os.path.exists(script_path)),
                "runtime_script_path": script_path or None,
                "config_value_count": config_value_count,
                "record_count": record_count,
                "latest_record_at": _iso(latest_record_at),
            }
        )
        return payload

    async def _build_extension_detail(self, manifest) -> dict[str, Any]:
        stored_settings = await extension_storage_service.list_settings(
            manifest.id,
            include_secrets=True,
        )
        declared_keys = {field.key for field in manifest.config_fields}
        config_fields: list[dict[str, Any]] = []

        for field in manifest.config_fields:
            raw_value = stored_settings.get(field.key)
            has_value = raw_value is not None and str(raw_value) != ""
            field_payload = field.to_dict()
            field_payload.update(
                {
                    "value": "" if field.secret or raw_value is None else str(raw_value),
                    "has_value": has_value,
                }
            )
            config_fields.append(field_payload)

        recent_records = await extension_storage_service.list_records(
            manifest.id,
            limit=12,
            include_expired=True,
        )
        trigger_runs = await extension_storage_service.list_trigger_runs(
            manifest.id,
            limit=12,
        )
        script_path = _extension_script_path(manifest.local_path)

        return {
            "extension": await self._serialize_extension(manifest),
            "runtime": {
                "has_script": bool(script_path and os.path.exists(script_path)),
                "script_path": script_path or None,
            },
            "config": {
                "scope_type": "global",
                "fields": config_fields,
                "unknown_keys": sorted(key for key in stored_settings.keys() if key not in declared_keys),
            },
            "records": [
                {
                    "id": record.id,
                    "scope_type": record.scope_type,
                    "scope_id": record.scope_id,
                    "record_type": record.record_type,
                    "record_key": record.record_key,
                    "title": record.title,
                    "content_preview": _record_preview(record.content),
                    "created_at": _iso(record.created_at),
                    "updated_at": _iso(record.updated_at),
                    "expires_at": _iso(record.expires_at),
                }
                for record in recent_records
            ],
            "trigger_runs": [
                {
                    "id": run.id,
                    "trigger_name": run.trigger_name,
                    "last_run_at": _iso(run.last_run_at),
                    "last_status": run.last_status,
                    "last_error": run.last_error,
                    "updated_at": _iso(run.updated_at),
                }
                for run in trigger_runs
            ],
        }

    async def get_meta(self) -> dict[str, Any]:
        api_base = f"http://{settings.WEB_DASHBOARD_HOST}:{settings.WEB_DASHBOARD_PORT}/api"
        return {
            "name": "Echogram Web",
            "bot_name": settings.BOT_NAME,
            "api_base": api_base,
            "ui_url": settings.WEB_DASHBOARD_UI_URL or None,
            "telegram_retained_commands": ["/edit", "/preview", "/del", "/delete"],
            "web_focus_areas": ["logs", "prompt preview", "rag records", "subscriptions", "extensions"],
        }

    async def get_extensions(self) -> dict[str, Any]:
        catalog = extension_registry.get_catalog()
        items = []
        for manifest in extension_registry.list_extensions():
            items.append(await self._serialize_extension(manifest))
        catalog["items"] = items
        return catalog

    async def get_extension_detail(self, extension_id: str) -> dict[str, Any] | None:
        manifest = extension_registry.get_extension(extension_id)
        if not manifest:
            return None
        return await self._build_extension_detail(manifest)

    async def set_extension_enabled(
        self,
        extension_id: str,
        *,
        enabled: bool,
    ) -> dict[str, Any] | None:
        manifest = extension_registry.get_extension(extension_id)
        if not manifest:
            return None
        await extension_storage_service.set_extension_enabled(manifest.id, enabled)
        return await self._build_extension_detail(manifest)

    async def update_extension_config(
        self,
        extension_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any] | None:
        manifest = extension_registry.get_extension(extension_id)
        if not manifest:
            return None

        values = payload.get("values", payload)
        clear_keys = payload.get("clear_keys", [])
        if not isinstance(values, dict):
            raise ValueError("config values must be an object")
        if not isinstance(clear_keys, list):
            raise ValueError("clear_keys must be a list")

        declared_fields = {field.key: field for field in manifest.config_fields}
        unknown_value_keys = [key for key in values.keys() if key not in declared_fields]
        unknown_clear_keys = [key for key in clear_keys if key not in declared_fields]
        if unknown_value_keys or unknown_clear_keys:
            unknown_keys = ", ".join(sorted({*unknown_value_keys, *unknown_clear_keys}))
            raise ValueError(f"unknown extension config field(s): {unknown_keys}")

        for field_key in clear_keys:
            await extension_storage_service.delete_setting(manifest.id, field_key)

        for field_key, raw_value in values.items():
            field = declared_fields[field_key]
            normalized = "" if raw_value is None else str(raw_value)

            if field.secret:
                if not normalized:
                    continue
                await extension_storage_service.set_setting(
                    manifest.id,
                    field_key,
                    normalized,
                    is_secret=True,
                )
                continue

            if not normalized:
                await extension_storage_service.delete_setting(manifest.id, field_key)
            else:
                await extension_storage_service.set_setting(
                    manifest.id,
                    field_key,
                    normalized,
                    is_secret=field.secret,
                )

        return await self._build_extension_detail(manifest)

    async def install_extension(
        self,
        payload: dict[str, Any] | None = None,
        *,
        upload_filename: str | None = None,
        upload_bytes: bytes | None = None,
    ) -> dict[str, Any]:
        try:
            if upload_bytes is not None:
                overwrite = False
                if payload:
                    overwrite = str(payload.get("overwrite", "")).strip().lower() in {"1", "true", "yes", "on"}
                result = await extension_installer.install_from_zip_bytes(
                    upload_filename or "upload.zip",
                    upload_bytes,
                    overwrite=overwrite,
                )
            else:
                result = await extension_installer.install(payload or {})

            extension_payload = result.get("extension")
            extension_id = ""
            if isinstance(extension_payload, dict):
                extension_id = str(extension_payload.get("id") or "").strip()
            manifest = extension_registry.get_extension(extension_id) if extension_id else None
            if manifest:
                result["extension"] = await self._serialize_extension(manifest)
            return result
        except ExtensionInstallError:
            raise

    async def get_overview(self) -> dict[str, Any]:
        configs = await config_service.get_all_settings()
        subscriptions = await news_push_service.get_all_subscriptions()

        total_subscriptions = len(subscriptions)
        active_subscriptions = sum(1 for sub in subscriptions if sub.is_active)
        error_subscriptions = sum(1 for sub in subscriptions if sub.status == "error")

        return {
            "meta": await self.get_meta(),
            "settings": {
                "api_base_url": configs.get("api_base_url"),
                "model_name": configs.get("model_name"),
                "summary_model_name": configs.get("summary_model_name"),
                "vector_model_name": configs.get("vector_model_name", "text-embedding-3-small"),
                "media_model": configs.get("media_model"),
                "timezone": configs.get("timezone", "UTC"),
                "history_tokens": _safe_int(configs.get("history_tokens"), settings.HISTORY_WINDOW_TOKENS),
                "aggregation_latency": configs.get("aggregation_latency", "10.0"),
                "active_hours": {
                    "start": configs.get("agentic_active_start", "08:00"),
                    "end": configs.get("agentic_active_end", "23:00"),
                },
                "idle_threshold_minutes": _safe_int(configs.get("agentic_idle_threshold"), 30),
            },
            "subscriptions": {
                "total": total_subscriptions,
                "active": active_subscriptions,
                "error": error_subscriptions,
            },
            "recent_chats": await self.list_chats(limit=8),
        }

    async def get_settings(self) -> dict[str, str]:
        return await config_service.get_all_settings()

    async def update_settings(self, changes: dict[str, Any]) -> dict[str, str]:
        updated: dict[str, str] = {}
        for key, value in changes.items():
            if not isinstance(key, str) or not key.strip():
                continue
            normalized = "" if value is None else str(value)
            await config_service.set_value(key, normalized)
            updated[key] = normalized
        return updated

    async def _get_summary_updated_at(self, chat_id: int) -> str | None:
        status = await summary_service.get_status(chat_id)
        return _iso(status.get("updated_at"))

    async def list_chats(self, limit: int = 20) -> list[dict[str, Any]]:
        whitelist_map = await _load_whitelist_map()

        async for session in get_db_session():
            last_message_at = func.max(History.timestamp).label("last_message_at")
            message_count = func.count(History.id).label("message_count")
            stmt = (
                select(History.chat_id, last_message_at, message_count)
                .group_by(History.chat_id)
                .order_by(desc(last_message_at))
                .limit(limit)
            )
            rows = (await session.execute(stmt)).all()

        chats: list[dict[str, Any]] = []
        seen: set[int] = set()

        for chat_id, last_seen, total_messages in rows:
            if chat_id > 0 and chat_id not in whitelist_map:
                continue
            whitelist_entry = whitelist_map.get(chat_id)
            chats.append(
                {
                    "chat_id": chat_id,
                    "label": whitelist_entry.description if whitelist_entry and whitelist_entry.description else f"Chat {chat_id}",
                    "chat_type": whitelist_entry.type if whitelist_entry else ("group" if chat_id < 0 else "private"),
                    "whitelisted": whitelist_entry is not None,
                    "last_message_at": _iso(last_seen),
                    "total_messages": int(total_messages or 0),
                    "summary_updated_at": await self._get_summary_updated_at(chat_id),
                }
            )
            seen.add(chat_id)

        for chat_id, whitelist_entry in whitelist_map.items():
            if chat_id in seen:
                continue
            chats.append(
                {
                    "chat_id": chat_id,
                    "label": whitelist_entry.description or f"Chat {chat_id}",
                    "chat_type": whitelist_entry.type,
                    "whitelisted": True,
                    "last_message_at": None,
                    "total_messages": 0,
                    "summary_updated_at": await self._get_summary_updated_at(chat_id),
                }
            )

        return chats

    async def chat_exists(self, chat_id: int) -> bool:
        async for session in get_db_session():
            history_hit = await session.execute(select(History.id).where(History.chat_id == chat_id).limit(1))
            if history_hit.scalar_one_or_none() is not None:
                return True
            whitelist_hit = await session.execute(select(Whitelist.chat_id).where(Whitelist.chat_id == chat_id))
            return whitelist_hit.scalar_one_or_none() is not None

    async def get_chat_detail(self, chat_id: int, recent_limit: int = 12) -> dict[str, Any] | None:
        if not await self.chat_exists(chat_id):
            return None

        configs = await config_service.get_all_settings()
        history_tokens = _safe_int(configs.get("history_tokens"), settings.HISTORY_WINDOW_TOKENS)
        stats = await history_service.get_session_stats(chat_id, history_tokens)
        summary_status = await summary_service.get_status(chat_id)
        summary_text = await summary_service.get_summary(chat_id)
        rag_stats = await rag_service.get_vector_stats(chat_id)
        whitelist_map = await _load_whitelist_map()
        whitelist_entry = whitelist_map.get(chat_id)

        async for session in get_db_session():
            stmt = (
                select(History)
                .where(History.chat_id == chat_id)
                .order_by(History.id.desc())
                .limit(recent_limit)
            )
            recent_messages = list(reversed((await session.execute(stmt)).scalars().all()))

        return {
            "chat_id": chat_id,
            "label": whitelist_entry.description if whitelist_entry and whitelist_entry.description else f"Chat {chat_id}",
            "chat_type": whitelist_entry.type if whitelist_entry else ("group" if chat_id < 0 else "private"),
            "whitelisted": whitelist_entry is not None,
            "settings": {
                "history_tokens": history_tokens,
                "timezone": configs.get("timezone", "UTC"),
            },
            "session_stats": stats,
            "summary": {
                "content": summary_text,
                "last_summarized_id": summary_status.get("last_id", 0),
                "updated_at": _iso(summary_status.get("updated_at")),
            },
            "rag_stats": rag_stats,
            "recent_messages": [
                {
                    "db_id": message.id,
                    "message_id": message.message_id,
                    "role": message.role,
                    "message_type": message.message_type,
                    "timestamp": _iso(message.timestamp),
                    "content": message.content or "",
                }
                for message in recent_messages
            ],
        }

    async def get_recent_messages(
        self,
        chat_id: int,
        *,
        limit: int = 12,
        offset: int = 0,
    ) -> dict[str, Any] | None:
        if not await self.chat_exists(chat_id):
            return None

        limit = _bounded(limit, default=12, maximum=100)
        offset = _safe_offset(offset)

        async for session in get_db_session():
            total_stmt = select(func.count(History.id)).where(History.chat_id == chat_id)
            total = int((await session.execute(total_stmt)).scalar_one() or 0)

            stmt = (
                select(History)
                .where(History.chat_id == chat_id)
                .order_by(History.id.desc())
                .offset(offset)
                .limit(limit)
            )
            messages = list(reversed((await session.execute(stmt)).scalars().all()))

        items = [
            {
                "db_id": message.id,
                "message_id": message.message_id,
                "role": message.role,
                "message_type": message.message_type,
                "timestamp": _iso(message.timestamp),
                "content": message.content or "",
            }
            for message in messages
        ]
        return _page(items, total=total, limit=limit, offset=offset)

    async def build_prompt_preview(self, chat_id: int) -> dict[str, Any] | None:
        chat_detail = await self.get_chat_detail(chat_id, recent_limit=12)
        if not chat_detail:
            return None

        try:
            last_message_type = await media_service.get_last_user_message_type(chat_id)
        except Exception as exc:
            logger.warning("Prompt preview could not detect message type for %s: %s", chat_id, exc)
            last_message_type = "text"

        simulated_has_voice = last_message_type == "voice"
        simulated_has_image = last_message_type == "image"

        dynamic_summary = await summary_service.get_summary(chat_id)
        configs = await config_service.get_all_settings()
        soul_prompt = configs.get("system_prompt")
        timezone_name = configs.get("timezone", "UTC")

        system_protocol = prompt_builder.build_system_prompt(
            soul_prompt=soul_prompt,
            timezone=timezone_name,
            dynamic_summary=None,
            has_voice=simulated_has_voice,
            has_image=simulated_has_image,
        )

        memory_block = prompt_builder.build_memory_block(dynamic_summary).strip()
        target_tokens = _safe_int(configs.get("history_tokens"), settings.HISTORY_WINDOW_TOKENS)
        history_messages = await history_service.get_token_controlled_context(chat_id, target_tokens=target_tokens)

        try:
            timezone = pytz.timezone(timezone_name)
        except Exception:
            timezone = pytz.UTC

        lines = [memory_block or "# Long-term Memory\n> (No summary yet)", "", "# Recent Context"]
        if not history_messages:
            lines.append("> (No recent history)")
        else:
            for message in history_messages:
                timestamp = message.timestamp
                if timestamp:
                    if timestamp.tzinfo is None:
                        timestamp = timestamp.replace(tzinfo=pytz.UTC)
                    time_text = timestamp.astimezone(timezone).strftime("%Y-%m-%d %H:%M:%S")
                else:
                    time_text = "Unknown"
                lines.append(
                    f"[MSG {message.message_id or '?'}] [{time_text}] [{(message.message_type or 'text').upper()}] "
                    f"{message.role.upper()}: {_clip(_visible_content(message.content), 240)}"
                )

        return {
            "chat_id": chat_id,
            "chat_label": chat_detail["label"],
            "timezone": timezone_name,
            "last_message_type": last_message_type,
            "generated_at": _iso(datetime.utcnow()),
            "system_protocol": system_protocol,
            "memory_context": "\n".join(lines).strip(),
        }

    async def get_rag_records(
        self,
        chat_id: int,
        *,
        limit: int = 12,
        offset: int = 0,
    ) -> dict[str, Any] | None:
        if not await self.chat_exists(chat_id):
            return None

        limit = _bounded(limit, default=12, maximum=100)
        offset = _safe_offset(offset)

        async for session in get_db_session():
            total_stmt = select(func.count(RagStatus.msg_id)).where(RagStatus.chat_id == chat_id)
            total = int((await session.execute(total_stmt)).scalar_one() or 0)

            stmt = (
                select(RagStatus, History)
                .join(History, History.id == RagStatus.msg_id)
                .where(RagStatus.chat_id == chat_id)
                .order_by(RagStatus.processed_at.desc())
                .offset(offset)
                .limit(limit)
            )
            rows = (await session.execute(stmt)).all()

        items = [
            {
                "msg_id": rag.msg_id,
                "status": rag.status,
                "processed_at": _iso(rag.processed_at),
                "denoised_content": rag.denoised_content or "",
                "role": history.role,
                "message_type": history.message_type,
                "source_content": history.content or "",
            }
            for rag, history in rows
        ]
        return _page(items, total=total, limit=limit, offset=offset)

    async def rebuild_rag(self, chat_id: int) -> dict[str, Any]:
        await rag_service.rebuild_index(chat_id)
        return {"ok": True, "chat_id": chat_id}

    async def get_recent_logs(self, char_limit: int = 8000) -> dict[str, Any]:
        log_path = os.path.join("logs", "echogram.log")
        if not os.path.exists(log_path):
            return {"path": log_path, "content": "", "truncated": False}

        with open(log_path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            start = max(0, size - char_limit)
            handle.seek(start, os.SEEK_SET)
            content = handle.read().decode("utf-8", errors="replace")

        return {
            "path": log_path,
            "content": content,
            "truncated": start > 0,
        }

    async def get_subscriptions(self) -> list[dict[str, Any]]:
        async for session in get_db_session():
            target_count = func.count(ChatSubscription.id).label("target_count")
            stmt = (
                select(NewsSubscription, target_count)
                .outerjoin(
                    ChatSubscription,
                    and_(
                        ChatSubscription.subscription_id == NewsSubscription.id,
                        ChatSubscription.is_active.is_(True),
                    ),
                )
                .group_by(NewsSubscription.id)
                .order_by(NewsSubscription.name.asc())
            )
            rows = (await session.execute(stmt)).all()

        return [
            {
                "id": subscription.id,
                "name": subscription.name,
                "route": subscription.route,
                "is_active": subscription.is_active,
                "status": subscription.status,
                "target_count": int(target_count or 0),
                "last_publish_time": _iso(subscription.last_publish_time),
                "last_check_time": _iso(subscription.last_check_time),
                "last_error": subscription.last_error,
                "error_count": subscription.error_count,
            }
            for subscription, target_count in rows
        ]


echogram_web_service = EchogramWebService()
