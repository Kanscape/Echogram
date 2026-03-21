"""Extension runtime state, settings, and records."""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, get_utc_now


class ExtensionState(Base):
    """Persisted enablement state for an extension."""

    __tablename__ = "extension_states"

    extension_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_utc_now,
        onupdate=get_utc_now,
    )


class ExtensionSetting(Base):
    """Extension-owned key/value storage."""

    __tablename__ = "extension_settings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    extension_id: Mapped[str] = mapped_column(String(120), index=True)
    scope_type: Mapped[str] = mapped_column(String(16), default="global")
    scope_id: Mapped[int] = mapped_column(BigInteger, default=0)
    key: Mapped[str] = mapped_column(String(120))
    value: Mapped[str] = mapped_column(Text, default="")
    is_secret: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_utc_now,
        onupdate=get_utc_now,
    )

    __table_args__ = (
        UniqueConstraint(
            "extension_id",
            "scope_type",
            "scope_id",
            "key",
            name="uq_extension_setting_scope_key",
        ),
        Index(
            "idx_extension_setting_scope",
            "extension_id",
            "scope_type",
            "scope_id",
        ),
    )


class ExtensionRecord(Base):
    """Extension-owned structured text records, such as cached summaries."""

    __tablename__ = "extension_records"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    extension_id: Mapped[str] = mapped_column(String(120), index=True)
    scope_type: Mapped[str] = mapped_column(String(16), default="global")
    scope_id: Mapped[int] = mapped_column(BigInteger, default=0)
    record_type: Mapped[str] = mapped_column(String(120), index=True)
    record_key: Mapped[str] = mapped_column(String(200), nullable=True)
    title: Mapped[str] = mapped_column(String(255), nullable=True)
    content: Mapped[str] = mapped_column(Text, default="")
    metadata_json: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=get_utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_utc_now,
        onupdate=get_utc_now,
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)

    __table_args__ = (
        Index(
            "idx_extension_record_lookup",
            "extension_id",
            "record_type",
            "scope_type",
            "scope_id",
            "updated_at",
        ),
    )


class ExtensionTriggerRun(Base):
    """Last-run status for scheduled extension triggers."""

    __tablename__ = "extension_trigger_runs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    extension_id: Mapped[str] = mapped_column(String(120), index=True)
    trigger_name: Mapped[str] = mapped_column(String(120))
    last_run_at: Mapped[datetime] = mapped_column(DateTime, default=get_utc_now)
    last_status: Mapped[str] = mapped_column(String(32), default="pending")
    last_error: Mapped[str] = mapped_column(Text, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=get_utc_now,
        onupdate=get_utc_now,
    )

    __table_args__ = (
        UniqueConstraint(
            "extension_id",
            "trigger_name",
            name="uq_extension_trigger_run",
        ),
    )
