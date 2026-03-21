from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


def _string(value: Any, fallback: str = "") -> str:
    if value is None:
        return fallback
    return str(value)


def _bool(value: Any, fallback: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return fallback
    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return fallback


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if item is not None]


@dataclass(frozen=True)
class ExtensionToolManifest:
    name: str
    description: str = ""
    read_only: bool = True

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ExtensionToolManifest":
        return cls(
            name=_string(data.get("name")),
            description=_string(data.get("description")),
            read_only=_bool(data.get("read_only"), True),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "read_only": self.read_only,
        }


@dataclass(frozen=True)
class ExtensionConfigFieldManifest:
    key: str
    label: str
    field_type: str = "text"
    required: bool = False
    secret: bool = False
    help: str = ""
    placeholder: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ExtensionConfigFieldManifest":
        return cls(
            key=_string(data.get("key")),
            label=_string(data.get("label") or data.get("key")),
            field_type=_string(data.get("type"), "text"),
            required=_bool(data.get("required")),
            secret=_bool(data.get("secret")),
            help=_string(data.get("help")),
            placeholder=_string(data.get("placeholder")),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "label": self.label,
            "type": self.field_type,
            "required": self.required,
            "secret": self.secret,
            "help": self.help,
            "placeholder": self.placeholder,
        }


@dataclass(frozen=True)
class DashboardPanelManifest:
    slot: str
    kind: str
    title: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "DashboardPanelManifest":
        return cls(
            slot=_string(data.get("slot")),
            kind=_string(data.get("kind")),
            title=_string(data.get("title")),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "slot": self.slot,
            "kind": self.kind,
            "title": self.title,
        }


@dataclass(frozen=True)
class ExtensionTriggerMatchManifest:
    url_domains: tuple[str, ...] = field(default_factory=tuple)
    keywords: tuple[str, ...] = field(default_factory=tuple)
    regex_patterns: tuple[str, ...] = field(default_factory=tuple)

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "ExtensionTriggerMatchManifest":
        data = data or {}
        return cls(
            url_domains=tuple(_string_list(data.get("url_domains"))),
            keywords=tuple(_string_list(data.get("keywords"))),
            regex_patterns=tuple(_string_list(data.get("regex"))),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "url_domains": list(self.url_domains),
            "keywords": list(self.keywords),
            "regex": list(self.regex_patterns),
        }

    @property
    def is_empty(self) -> bool:
        return not (self.url_domains or self.keywords or self.regex_patterns)


@dataclass(frozen=True)
class ExtensionTriggerManifest:
    name: str
    trigger_type: str
    description: str = ""
    scopes: tuple[str, ...] = field(default_factory=tuple)
    schedule: str = ""
    match: ExtensionTriggerMatchManifest = field(default_factory=ExtensionTriggerMatchManifest)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ExtensionTriggerManifest":
        trigger_name = _string(data.get("name")) or _string(data.get("type"))
        return cls(
            name=trigger_name,
            trigger_type=_string(data.get("type")),
            description=_string(data.get("description")),
            scopes=tuple(_string_list(data.get("scopes"))),
            schedule=_string(data.get("schedule")),
            match=ExtensionTriggerMatchManifest.from_dict(
                data.get("match") if isinstance(data.get("match"), dict) else None
            ),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "type": self.trigger_type,
            "description": self.description,
            "scopes": list(self.scopes),
            "schedule": self.schedule,
            "match": self.match.to_dict(),
        }

    @property
    def is_passive(self) -> bool:
        return self.trigger_type in {"global_passive", "scoped_passive"}

    @property
    def is_scheduled(self) -> bool:
        return self.trigger_type == "global_scheduled"


@dataclass(frozen=True)
class ExtensionManifest:
    id: str
    name: str
    version: str
    purpose: str
    description: str = ""
    author: str = ""
    homepage: str = ""
    source_type: str = "local_dir"
    status: str = "discovered"
    installed: bool = True
    enabled: bool = False
    local_path: str = ""
    permissions: tuple[str, ...] = field(default_factory=tuple)
    tools: tuple[ExtensionToolManifest, ...] = field(default_factory=tuple)
    triggers: tuple[ExtensionTriggerManifest, ...] = field(default_factory=tuple)
    config_fields: tuple[ExtensionConfigFieldManifest, ...] = field(default_factory=tuple)
    dashboard_panels: tuple[DashboardPanelManifest, ...] = field(default_factory=tuple)

    @classmethod
    def from_dict(
        cls,
        data: dict[str, Any],
        *,
        local_path: str = "",
        source_type: str = "local_dir",
    ) -> "ExtensionManifest":
        config_schema = data.get("config_schema")
        field_defs: list[dict[str, Any]] = []
        if isinstance(config_schema, dict):
            raw_fields = config_schema.get("fields")
            if isinstance(raw_fields, list):
                field_defs = [item for item in raw_fields if isinstance(item, dict)]

        dashboard = data.get("dashboard")
        panel_defs: list[dict[str, Any]] = []
        if isinstance(dashboard, dict):
            raw_panels = dashboard.get("panels")
            if isinstance(raw_panels, list):
                panel_defs = [item for item in raw_panels if isinstance(item, dict)]

        raw_tools = data.get("tools")
        tool_defs = [item for item in raw_tools if isinstance(item, dict)] if isinstance(raw_tools, list) else []
        raw_triggers = data.get("triggers")
        trigger_defs = [item for item in raw_triggers if isinstance(item, dict)] if isinstance(raw_triggers, list) else []

        ext_id = _string(data.get("id")) or _string(data.get("name"))
        return cls(
            id=ext_id,
            name=_string(data.get("name") or ext_id),
            version=_string(data.get("version"), "0.0.0"),
            purpose=_string(data.get("purpose")),
            description=_string(data.get("description")),
            author=_string(data.get("author")),
            homepage=_string(data.get("homepage")),
            source_type=_string(data.get("source_type"), source_type),
            status=_string(data.get("status"), "discovered"),
            installed=_bool(data.get("installed"), True),
            enabled=_bool(data.get("enabled"), False),
            local_path=local_path,
            permissions=tuple(_string_list(data.get("permissions"))),
            tools=tuple(ExtensionToolManifest.from_dict(item) for item in tool_defs),
            triggers=tuple(ExtensionTriggerManifest.from_dict(item) for item in trigger_defs),
            config_fields=tuple(ExtensionConfigFieldManifest.from_dict(item) for item in field_defs),
            dashboard_panels=tuple(DashboardPanelManifest.from_dict(item) for item in panel_defs),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "version": self.version,
            "purpose": self.purpose,
            "description": self.description,
            "author": self.author,
            "homepage": self.homepage,
            "source_type": self.source_type,
            "status": self.status,
            "installed": self.installed,
            "enabled": self.enabled,
            "local_path": self.local_path,
            "permissions": list(self.permissions),
            "tools": [tool.to_dict() for tool in self.tools],
            "triggers": [trigger.to_dict() for trigger in self.triggers],
            "config_fields": [field.to_dict() for field in self.config_fields],
            "dashboard_panels": [panel.to_dict() for panel in self.dashboard_panels],
        }


@dataclass(frozen=True)
class ExtensionImportMethod:
    id: str
    label: str
    description: str
    recommended: bool = False
    enabled: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "label": self.label,
            "description": self.description,
            "recommended": self.recommended,
            "enabled": self.enabled,
        }
