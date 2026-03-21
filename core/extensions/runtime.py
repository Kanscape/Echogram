from __future__ import annotations

import importlib.util
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from types import ModuleType
from typing import Any

from config.settings import settings
from core.config_service import config_service
from core.llm_utils import simple_chat
from utils.logger import logger

from .media_helper import ExtensionMediaHelper
from .manifest import ExtensionManifest, ExtensionTriggerManifest
from .matcher import ExtensionEventContext, ExtensionTriggerMatcher
from .registry import extension_registry
from .storage import ExtensionStorageService, extension_storage_service


def _normalize_tool_definition(tool: dict[str, Any]) -> dict[str, Any] | None:
    if not isinstance(tool, dict):
        return None

    tool_type = str(tool.get("type") or "function").strip().lower()
    function_def = tool.get("function")
    if tool_type != "function" or not isinstance(function_def, dict):
        return None

    name = str(function_def.get("name") or "").strip()
    if not name:
        return None

    normalized = {
        "type": "function",
        "function": {
            "name": name,
            "description": str(function_def.get("description") or "").strip(),
            "parameters": function_def.get("parameters")
            if isinstance(function_def.get("parameters"), dict)
            else {
                "type": "object",
                "properties": {},
            },
        },
    }
    return normalized


def _normalize_prompt_injection(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (list, tuple)):
        parts = [_normalize_prompt_injection(item) for item in value]
        return "\n".join(part for part in parts if part)
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False, indent=2)
    return str(value).strip()


def _stringify_tool_result(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, (dict, list, tuple)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def _normalize_summary_focus(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _parse_schedule_interval(schedule: str) -> timedelta | None:
    normalized = (schedule or "").strip().lower()
    if not normalized:
        return None
    if normalized == "hourly":
        return timedelta(hours=1)
    if normalized == "daily":
        return timedelta(days=1)
    if normalized.endswith("m") and normalized[:-1].isdigit():
        return timedelta(minutes=max(1, int(normalized[:-1])))
    if normalized.endswith("h") and normalized[:-1].isdigit():
        return timedelta(hours=max(1, int(normalized[:-1])))
    if normalized.endswith("d") and normalized[:-1].isdigit():
        return timedelta(days=max(1, int(normalized[:-1])))
    return None


def _parse_daily_clock(schedule: str) -> tuple[int, int] | None:
    normalized = (schedule or "").strip()
    if len(normalized) != 5 or ":" not in normalized:
        return None
    hour_text, minute_text = normalized.split(":", 1)
    if not (hour_text.isdigit() and minute_text.isdigit()):
        return None
    hour = int(hour_text)
    minute = int(minute_text)
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    return hour, minute


class ExtensionSummaryHelper:
    _PERMISSION = "llm:summary"
    _MAX_INPUT_CHARS = 20000
    _MAX_OUTPUT_TOKENS = 1200

    def __init__(self, manifest: ExtensionManifest):
        self._manifest = manifest

    def _ensure_allowed(self) -> None:
        permissions = {permission.strip().lower() for permission in self._manifest.permissions if permission}
        if self._PERMISSION not in permissions:
            raise PermissionError(
                f"Extension '{self._manifest.id}' must declare permission '{self._PERMISSION}' "
                "before calling the summary helper."
            )

    async def summarize(
        self,
        text: Any,
        *,
        focus: str = "",
        prompt_override: str = "",
        max_input_chars: int = 12000,
        max_tokens: int = 800,
    ) -> str:
        self._ensure_allowed()

        raw_text = str(text or "").strip()
        if not raw_text:
            return ""

        input_limit = max(200, min(int(max_input_chars or 12000), self._MAX_INPUT_CHARS))
        output_limit = max(64, min(int(max_tokens or 800), self._MAX_OUTPUT_TOKENS))
        clipped_text = raw_text[:input_limit]
        clipped = len(clipped_text) < len(raw_text)

        configs = await config_service.get_all_settings()
        model_name = (
            (configs.get("summary_model_name") or "").strip()
            or settings.SUMMARY_MODEL
            or (configs.get("model_name") or "").strip()
            or settings.OPENAI_MODEL_NAME
        )
        focus_text = _normalize_summary_focus(focus)
        system_prompt = (
            "You are a safe summarization utility for Echogram extensions. "
            "Your job is to clean noisy raw data and return a compact, faithful plain-text summary. "
            "Keep only facts, key entities, timestamps, links, and actionable details. "
            "Remove duplicated fragments, boilerplate, tracking noise, and irrelevant markup. "
            "Do not roleplay. Do not answer as a chatbot. Output plain text only."
        )

        primary_instruction = (
            (prompt_override or "").strip()
            or "Please clean the raw data below and rewrite it as a concise summary that is safe to store in the extension database or feed back into the main model."
        )
        user_parts = [primary_instruction]
        if focus_text:
            user_parts.append(f"Focus:\n{focus_text}")
        if clipped:
            user_parts.append(
                f"Note: the raw input was truncated to the first {input_limit} characters for safety."
            )
        user_parts.append(f"Raw data:\n{clipped_text}")

        result = await simple_chat(
            model_name,
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": "\n\n".join(user_parts)},
            ],
            temperature=0.2,
            max_tokens=output_limit,
        )
        return (result or "").strip()

    async def clean_text(
        self,
        text: Any,
        *,
        focus: str = "",
        prompt_override: str = "",
        max_input_chars: int = 12000,
        max_tokens: int = 800,
    ) -> str:
        return await self.summarize(
            text,
            focus=focus,
            prompt_override=prompt_override,
            max_input_chars=max_input_chars,
            max_tokens=max_tokens,
        )


@dataclass(frozen=True)
class ExtensionRuntimeContext:
    manifest: ExtensionManifest
    storage: ExtensionStorageService
    summary: ExtensionSummaryHelper
    media: ExtensionMediaHelper
    chat_id: int | None = None
    scope: str = ""
    text: str = ""
    matched_triggers: tuple[ExtensionTriggerManifest, ...] = field(default_factory=tuple)
    trigger: ExtensionTriggerManifest | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def extension_id(self) -> str:
        return self.manifest.id


class EchogramExtension:
    def __init__(self, manifest: ExtensionManifest):
        self.manifest = manifest

    def get_tools(self, context: ExtensionRuntimeContext) -> list[dict[str, Any]]:
        return []

    async def execute_tool(
        self,
        tool_name: str,
        arguments: dict[str, Any],
        context: ExtensionRuntimeContext,
    ) -> Any:
        raise NotImplementedError(f"{self.manifest.id} does not implement tool '{tool_name}'")

    async def build_prompt_injection(self, context: ExtensionRuntimeContext) -> Any:
        return ""

    async def on_scheduled_trigger(
        self,
        trigger: ExtensionTriggerManifest,
        context: ExtensionRuntimeContext,
    ) -> None:
        return None


@dataclass(frozen=True)
class LoadedExtensionMatch:
    manifest: ExtensionManifest
    instance: EchogramExtension
    context: ExtensionRuntimeContext


class ActiveToolRegistry:
    def __init__(self):
        self._tools: list[dict[str, Any]] = []
        self._bindings: dict[str, LoadedExtensionMatch] = {}

    @property
    def tools(self) -> list[dict[str, Any]]:
        return list(self._tools)

    @property
    def names(self) -> tuple[str, ...]:
        return tuple(self._bindings.keys())

    def add_tools(
        self,
        loaded_match: LoadedExtensionMatch,
        tool_definitions: list[dict[str, Any]],
    ) -> None:
        for raw_tool in tool_definitions:
            normalized = _normalize_tool_definition(raw_tool)
            if normalized is None:
                continue
            name = normalized["function"]["name"]
            if name in self._bindings:
                logger.warning(
                    "Duplicate extension tool name '%s'; keeping first registration.",
                    name,
                )
                continue
            self._bindings[name] = loaded_match
            self._tools.append(normalized)

    async def execute(self, tool_name: str, arguments: dict[str, Any]) -> str:
        loaded_match = self._bindings.get(tool_name)
        if loaded_match is None:
            raise ValueError(f"Unknown extension tool: {tool_name}")

        raw_result = await loaded_match.instance.execute_tool(
            tool_name,
            arguments,
            loaded_match.context,
        )
        return _stringify_tool_result(raw_result)


@dataclass(frozen=True)
class ResolvedExtensionRuntime:
    matches: tuple[LoadedExtensionMatch, ...]
    prompt_injection: str
    tool_registry: ActiveToolRegistry

    @property
    def has_tools(self) -> bool:
        return bool(self.tool_registry.tools)

    @property
    def extension_ids(self) -> tuple[str, ...]:
        return tuple(match.manifest.id for match in self.matches)


class ExtensionRuntimeService:
    def __init__(self, storage: ExtensionStorageService | None = None):
        self._storage = storage or extension_storage_service
        self._instance_cache: dict[str, tuple[float, EchogramExtension]] = {}

    async def is_enabled(self, manifest: ExtensionManifest) -> bool:
        return await self._storage.get_extension_enabled(
            manifest.id,
            default=bool(manifest.enabled),
        )

    async def resolve_runtime(
        self,
        *,
        chat_id: int | None,
        scope: str,
        text: str = "",
        metadata: dict[str, Any] | None = None,
    ) -> ResolvedExtensionRuntime:
        event_context = ExtensionEventContext.from_text(scope=scope, text=text)
        matches: list[LoadedExtensionMatch] = []
        injections: list[str] = []
        tool_registry = ActiveToolRegistry()

        for manifest in extension_registry.list_extensions():
            if not await self.is_enabled(manifest):
                continue

            matched_triggers = ExtensionTriggerMatcher.match_manifest(manifest, event_context)
            if not matched_triggers:
                continue

            instance = self._load_instance(manifest)
            if instance is None:
                continue

            runtime_context = ExtensionRuntimeContext(
                manifest=manifest,
                storage=self._storage,
                summary=ExtensionSummaryHelper(manifest),
                media=ExtensionMediaHelper(manifest),
                chat_id=chat_id,
                scope=scope,
                text=text,
                matched_triggers=matched_triggers,
                metadata=dict(metadata or {}),
            )
            loaded_match = LoadedExtensionMatch(
                manifest=manifest,
                instance=instance,
                context=runtime_context,
            )
            matches.append(loaded_match)

            if hasattr(instance, "build_prompt_injection"):
                try:
                    injection = _normalize_prompt_injection(
                        await instance.build_prompt_injection(runtime_context)
                    )
                    if injection:
                        injections.append(f"[Extension: {manifest.name}]\n{injection}")
                except Exception as exc:
                    logger.error(
                        "Extension prompt injection failed for %s: %s",
                        manifest.id,
                        exc,
                        exc_info=True,
                    )

            if hasattr(instance, "get_tools"):
                try:
                    tool_registry.add_tools(
                        loaded_match,
                        list(instance.get_tools(runtime_context) or []),
                    )
                except Exception as exc:
                    logger.error(
                        "Extension tool discovery failed for %s: %s",
                        manifest.id,
                        exc,
                        exc_info=True,
                    )

        return ResolvedExtensionRuntime(
            matches=tuple(matches),
            prompt_injection="\n\n".join(part for part in injections if part),
            tool_registry=tool_registry,
        )

    async def run_scheduled_triggers(self) -> None:
        now = datetime.utcnow().replace(tzinfo=None)
        for manifest in extension_registry.list_extensions():
            if not await self.is_enabled(manifest):
                continue

            scheduled_triggers = [trigger for trigger in manifest.triggers if trigger.is_scheduled]
            if not scheduled_triggers:
                continue

            instance = self._load_instance(manifest)
            if instance is None:
                continue

            for trigger in scheduled_triggers:
                if not await self._trigger_is_due(manifest, trigger, now):
                    continue

                runtime_context = ExtensionRuntimeContext(
                    manifest=manifest,
                    storage=self._storage,
                    summary=ExtensionSummaryHelper(manifest),
                    media=ExtensionMediaHelper(manifest),
                    scope="scheduled",
                    matched_triggers=(trigger,),
                    trigger=trigger,
                )

                try:
                    await instance.on_scheduled_trigger(trigger, runtime_context)
                    await self._storage.mark_trigger_run(
                        manifest.id,
                        trigger.name,
                        status="ok",
                        ran_at=now,
                    )
                except Exception as exc:
                    logger.error(
                        "Scheduled extension trigger failed for %s/%s: %s",
                        manifest.id,
                        trigger.name,
                        exc,
                        exc_info=True,
                    )
                    await self._storage.mark_trigger_run(
                        manifest.id,
                        trigger.name,
                        status="error",
                        error=str(exc),
                        ran_at=now,
                    )

    async def _trigger_is_due(
        self,
        manifest: ExtensionManifest,
        trigger: ExtensionTriggerManifest,
        now: datetime,
    ) -> bool:
        run_state = await self._storage.get_trigger_run(manifest.id, trigger.name)
        last_run_at = run_state.last_run_at if run_state else None
        schedule = (trigger.schedule or "").strip()
        if not schedule:
            return last_run_at is None

        interval = _parse_schedule_interval(schedule)
        if interval is not None:
            if last_run_at is None:
                return True
            return now - last_run_at >= interval

        daily_clock = _parse_daily_clock(schedule)
        if daily_clock is not None:
            hour, minute = daily_clock
            scheduled_for_today = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
            if now < scheduled_for_today:
                return False
            if last_run_at is None:
                return True
            return last_run_at < scheduled_for_today

        logger.warning(
            "Unsupported extension trigger schedule '%s' for %s/%s",
            schedule,
            manifest.id,
            trigger.name,
        )
        return False

    def _load_instance(self, manifest: ExtensionManifest) -> EchogramExtension | None:
        script_path = Path(manifest.local_path) / "extension.py"
        if not script_path.exists():
            return None

        cache_key = manifest.id.lower()
        mtime = script_path.stat().st_mtime
        cached = self._instance_cache.get(cache_key)
        if cached and cached[0] == mtime:
            try:
                setattr(cached[1], "manifest", manifest)
            except Exception:
                pass
            return cached[1]

        module_name = f"echogram_extension_{manifest.id}"
        try:
            extension_dir = str(script_path.parent.resolve())
            if extension_dir not in sys.path:
                sys.path.insert(0, extension_dir)
            spec = importlib.util.spec_from_file_location(module_name, script_path)
            if spec is None or spec.loader is None:
                raise RuntimeError(f"Unable to create import spec for {script_path}")
            module = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = module
            spec.loader.exec_module(module)
            instance = self._instantiate_extension(module, manifest)
            self._instance_cache[cache_key] = (mtime, instance)
            return instance
        except Exception as exc:
            logger.error(
                "Failed to load extension runtime %s from %s: %s",
                manifest.id,
                script_path,
                exc,
                exc_info=True,
            )
            return None

    def _instantiate_extension(
        self,
        module: ModuleType,
        manifest: ExtensionManifest,
    ) -> EchogramExtension:
        if hasattr(module, "create_extension") and callable(module.create_extension):
            instance = module.create_extension(manifest)
        elif hasattr(module, "extension"):
            instance = module.extension
        elif hasattr(module, "Extension") and callable(module.Extension):
            instance = module.Extension(manifest)
        else:
            raise RuntimeError(
                "Extension runtime must expose create_extension(), extension, or Extension."
            )

        if isinstance(instance, type):
            instance = instance(manifest)

        if not isinstance(instance, EchogramExtension):
            if not hasattr(instance, "manifest"):
                setattr(instance, "manifest", manifest)
        else:
            instance.manifest = manifest

        return instance


extension_runtime_service = ExtensionRuntimeService()
