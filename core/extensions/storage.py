from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import delete, desc, select

from config.database import get_db_session
from models.base import get_utc_now
from models.extension import (
    ExtensionRecord,
    ExtensionSetting,
    ExtensionState,
    ExtensionTriggerRun,
)


def _scope_parts(chat_id: int | None) -> tuple[str, int]:
    if chat_id is None:
        return "global", 0
    return "chat", int(chat_id)


def _maybe_json_load(raw: str | None) -> Any:
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return raw


def _json_dump(value: Any) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False)


@dataclass(frozen=True)
class StoredExtensionRecord:
    id: int
    extension_id: str
    scope_type: str
    scope_id: int
    record_type: str
    record_key: str | None
    title: str | None
    content: str
    metadata: Any
    created_at: datetime
    updated_at: datetime
    expires_at: datetime | None

    @classmethod
    def from_model(cls, record: ExtensionRecord) -> "StoredExtensionRecord":
        return cls(
            id=record.id,
            extension_id=record.extension_id,
            scope_type=record.scope_type,
            scope_id=record.scope_id,
            record_type=record.record_type,
            record_key=record.record_key,
            title=record.title,
            content=record.content or "",
            metadata=_maybe_json_load(record.metadata_json),
            created_at=record.created_at,
            updated_at=record.updated_at,
            expires_at=record.expires_at,
        )


@dataclass(frozen=True)
class StoredExtensionTriggerRun:
    id: int
    extension_id: str
    trigger_name: str
    last_run_at: datetime
    last_status: str
    last_error: str | None
    updated_at: datetime

    @classmethod
    def from_model(cls, record: ExtensionTriggerRun) -> "StoredExtensionTriggerRun":
        return cls(
            id=record.id,
            extension_id=record.extension_id,
            trigger_name=record.trigger_name,
            last_run_at=record.last_run_at,
            last_status=record.last_status,
            last_error=record.last_error,
            updated_at=record.updated_at,
        )


class ExtensionStorageService:
    async def get_extension_enabled(
        self,
        extension_id: str,
        *,
        default: bool = False,
    ) -> bool:
        async for session in get_db_session():
            stmt = select(ExtensionState.enabled).where(ExtensionState.extension_id == extension_id)
            value = (await session.execute(stmt)).scalar_one_or_none()
            return default if value is None else bool(value)

    async def set_extension_enabled(self, extension_id: str, enabled: bool) -> None:
        async for session in get_db_session():
            stmt = select(ExtensionState).where(ExtensionState.extension_id == extension_id)
            state = (await session.execute(stmt)).scalar_one_or_none()
            if state is None:
                state = ExtensionState(extension_id=extension_id, enabled=enabled)
            else:
                state.enabled = enabled
            session.add(state)
            await session.commit()

    async def get_setting(
        self,
        extension_id: str,
        key: str,
        *,
        chat_id: int | None = None,
        default: Any = None,
        as_json: bool = False,
        fallback_to_global: bool = True,
    ) -> Any:
        scope_type, scope_id = _scope_parts(chat_id)
        candidates = [(scope_type, scope_id)]
        if fallback_to_global and (scope_type != "global" or scope_id != 0):
            candidates.append(("global", 0))

        async for session in get_db_session():
            for candidate_scope, candidate_id in candidates:
                stmt = select(ExtensionSetting.value).where(
                    ExtensionSetting.extension_id == extension_id,
                    ExtensionSetting.scope_type == candidate_scope,
                    ExtensionSetting.scope_id == candidate_id,
                    ExtensionSetting.key == key,
                )
                value = (await session.execute(stmt)).scalar_one_or_none()
                if value is not None:
                    return _maybe_json_load(value) if as_json else value
            return default

    async def set_setting(
        self,
        extension_id: str,
        key: str,
        value: Any,
        *,
        chat_id: int | None = None,
        is_secret: bool = False,
    ) -> None:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            stmt = select(ExtensionSetting).where(
                ExtensionSetting.extension_id == extension_id,
                ExtensionSetting.scope_type == scope_type,
                ExtensionSetting.scope_id == scope_id,
                ExtensionSetting.key == key,
            )
            record = (await session.execute(stmt)).scalar_one_or_none()
            if record is None:
                record = ExtensionSetting(
                    extension_id=extension_id,
                    scope_type=scope_type,
                    scope_id=scope_id,
                    key=key,
                )
            record.value = _json_dump(value)
            record.is_secret = bool(is_secret)
            session.add(record)
            await session.commit()

    async def delete_setting(
        self,
        extension_id: str,
        key: str,
        *,
        chat_id: int | None = None,
    ) -> None:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            await session.execute(
                delete(ExtensionSetting).where(
                    ExtensionSetting.extension_id == extension_id,
                    ExtensionSetting.scope_type == scope_type,
                    ExtensionSetting.scope_id == scope_id,
                    ExtensionSetting.key == key,
                )
            )
            await session.commit()

    async def list_settings(
        self,
        extension_id: str,
        *,
        chat_id: int | None = None,
        include_secrets: bool = False,
    ) -> dict[str, Any]:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            stmt = select(ExtensionSetting).where(
                ExtensionSetting.extension_id == extension_id,
                ExtensionSetting.scope_type == scope_type,
                ExtensionSetting.scope_id == scope_id,
            )
            rows = (await session.execute(stmt)).scalars().all()
            result: dict[str, Any] = {}
            for row in rows:
                if row.is_secret and not include_secrets:
                    continue
                result[row.key] = _maybe_json_load(row.value)
            return result

    async def put_record(
        self,
        extension_id: str,
        record_type: str,
        content: str,
        *,
        chat_id: int | None = None,
        record_key: str | None = None,
        title: str | None = None,
        metadata: Any = None,
        expires_at: datetime | None = None,
    ) -> StoredExtensionRecord:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            record: ExtensionRecord | None = None
            if record_key:
                stmt = select(ExtensionRecord).where(
                    ExtensionRecord.extension_id == extension_id,
                    ExtensionRecord.record_type == record_type,
                    ExtensionRecord.scope_type == scope_type,
                    ExtensionRecord.scope_id == scope_id,
                    ExtensionRecord.record_key == record_key,
                )
                record = (await session.execute(stmt)).scalar_one_or_none()

            if record is None:
                record = ExtensionRecord(
                    extension_id=extension_id,
                    record_type=record_type,
                    scope_type=scope_type,
                    scope_id=scope_id,
                    record_key=record_key,
                )

            record.title = title
            record.content = content or ""
            record.metadata_json = None if metadata is None else _json_dump(metadata)
            record.expires_at = expires_at
            session.add(record)
            await session.commit()
            await session.refresh(record)
            return StoredExtensionRecord.from_model(record)

    async def list_records(
        self,
        extension_id: str,
        *,
        record_type: str | None = None,
        chat_id: int | None = None,
        since_hours: float | None = None,
        include_expired: bool = False,
        limit: int = 20,
    ) -> list[StoredExtensionRecord]:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            stmt = select(ExtensionRecord).where(
                ExtensionRecord.extension_id == extension_id,
                ExtensionRecord.scope_type == scope_type,
                ExtensionRecord.scope_id == scope_id,
            )
            if record_type:
                stmt = stmt.where(ExtensionRecord.record_type == record_type)
            if since_hours is not None:
                threshold = get_utc_now() - timedelta(hours=max(0.0, float(since_hours)))
                stmt = stmt.where(ExtensionRecord.updated_at >= threshold)
            if not include_expired:
                now = get_utc_now()
                stmt = stmt.where(
                    (ExtensionRecord.expires_at.is_(None)) | (ExtensionRecord.expires_at > now)
                )
            stmt = stmt.order_by(desc(ExtensionRecord.updated_at)).limit(max(1, int(limit)))
            rows = (await session.execute(stmt)).scalars().all()
            return [StoredExtensionRecord.from_model(row) for row in rows]

    async def get_latest_record(
        self,
        extension_id: str,
        *,
        record_type: str | None = None,
        chat_id: int | None = None,
        since_hours: float | None = None,
        include_expired: bool = False,
    ) -> StoredExtensionRecord | None:
        rows = await self.list_records(
            extension_id,
            record_type=record_type,
            chat_id=chat_id,
            since_hours=since_hours,
            include_expired=include_expired,
            limit=1,
        )
        return rows[0] if rows else None

    async def get_record(
        self,
        extension_id: str,
        *,
        record_type: str,
        record_key: str,
        chat_id: int | None = None,
        include_expired: bool = False,
    ) -> StoredExtensionRecord | None:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            stmt = select(ExtensionRecord).where(
                ExtensionRecord.extension_id == extension_id,
                ExtensionRecord.scope_type == scope_type,
                ExtensionRecord.scope_id == scope_id,
                ExtensionRecord.record_type == record_type,
                ExtensionRecord.record_key == record_key,
            )
            if not include_expired:
                now = get_utc_now()
                stmt = stmt.where(
                    (ExtensionRecord.expires_at.is_(None)) | (ExtensionRecord.expires_at > now)
                )
            stmt = stmt.order_by(desc(ExtensionRecord.updated_at)).limit(1)
            row = (await session.execute(stmt)).scalars().first()
            return StoredExtensionRecord.from_model(row) if row else None

    async def delete_records(
        self,
        extension_id: str,
        *,
        record_type: str | None = None,
        chat_id: int | None = None,
        only_expired: bool = False,
    ) -> None:
        scope_type, scope_id = _scope_parts(chat_id)
        async for session in get_db_session():
            stmt = delete(ExtensionRecord).where(
                ExtensionRecord.extension_id == extension_id,
                ExtensionRecord.scope_type == scope_type,
                ExtensionRecord.scope_id == scope_id,
            )
            if record_type:
                stmt = stmt.where(ExtensionRecord.record_type == record_type)
            if only_expired:
                stmt = stmt.where(
                    ExtensionRecord.expires_at.is_not(None),
                    ExtensionRecord.expires_at <= get_utc_now(),
                )
            await session.execute(stmt)
            await session.commit()

    async def get_trigger_run(
        self,
        extension_id: str,
        trigger_name: str,
    ) -> ExtensionTriggerRun | None:
        async for session in get_db_session():
            stmt = select(ExtensionTriggerRun).where(
                ExtensionTriggerRun.extension_id == extension_id,
                ExtensionTriggerRun.trigger_name == trigger_name,
            )
            return (await session.execute(stmt)).scalar_one_or_none()

    async def mark_trigger_run(
        self,
        extension_id: str,
        trigger_name: str,
        *,
        status: str,
        error: str | None = None,
        ran_at: datetime | None = None,
    ) -> None:
        ran_at = ran_at or get_utc_now()
        async for session in get_db_session():
            stmt = select(ExtensionTriggerRun).where(
                ExtensionTriggerRun.extension_id == extension_id,
                ExtensionTriggerRun.trigger_name == trigger_name,
            )
            record = (await session.execute(stmt)).scalar_one_or_none()
            if record is None:
                record = ExtensionTriggerRun(
                    extension_id=extension_id,
                    trigger_name=trigger_name,
                )
            record.last_run_at = ran_at
            record.last_status = status
            record.last_error = error
            session.add(record)
            await session.commit()

    async def list_trigger_runs(
        self,
        extension_id: str,
        *,
        limit: int = 20,
    ) -> list[StoredExtensionTriggerRun]:
        async for session in get_db_session():
            stmt = (
                select(ExtensionTriggerRun)
                .where(ExtensionTriggerRun.extension_id == extension_id)
                .order_by(desc(ExtensionTriggerRun.updated_at))
                .limit(max(1, int(limit)))
            )
            rows = (await session.execute(stmt)).scalars().all()
            return [StoredExtensionTriggerRun.from_model(row) for row in rows]


extension_storage_service = ExtensionStorageService()
