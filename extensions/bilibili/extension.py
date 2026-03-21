from __future__ import annotations

from datetime import timedelta
from pathlib import Path
from typing import Any

from core.extensions import EchogramExtension, ExtensionRuntimeContext
from models.base import get_utc_now
from utils.logger import logger

try:
    from bilibili_support import BilibiliApiError, BilibiliClient, BilibiliVideoReference
except ModuleNotFoundError:
    from .bilibili_support import BilibiliApiError, BilibiliClient, BilibiliVideoReference


class Extension(EchogramExtension):
    _TOOL_NAME = "bilibili_get_video_summary"
    _SUMMARY_RECORD_TYPE = "video_summary"

    def get_tools(self, context: ExtensionRuntimeContext) -> list[dict[str, Any]]:
        if context.scope == "proactive_message":
            return []
        return [
            {
                "type": "function",
                "function": {
                    "name": self._TOOL_NAME,
                    "description": (
                        "获取指定 Bilibili 视频的摘要。优先使用中文字幕，失败时回退到低清视频的多模态摘要。"
                    ),
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "video_ref": {
                                "type": "string",
                                "description": "Bilibili 视频链接、BV 号或 av 号。",
                            },
                            "force_refresh": {
                                "type": "boolean",
                                "description": "是否跳过缓存，重新抓取并生成摘要。",
                            },
                        },
                        "required": ["video_ref"],
                    },
                },
            }
        ]

    async def execute_tool(
        self,
        tool_name: str,
        arguments: dict[str, Any],
        context: ExtensionRuntimeContext,
    ) -> Any:
        if tool_name != self._TOOL_NAME:
            raise ValueError(f"Unknown tool: {tool_name}")

        video_ref = str(arguments.get("video_ref") or "").strip()
        if not video_ref:
            raise ValueError("video_ref is required")

        reference = await self._resolve_reference(video_ref, context)
        if reference is None:
            raise ValueError("Unable to parse a Bilibili video reference from video_ref.")

        summary_payload = await self._get_or_create_summary(
            context,
            reference,
            force_refresh=bool(arguments.get("force_refresh")),
        )
        return summary_payload

    async def build_prompt_injection(self, context: ExtensionRuntimeContext) -> Any:
        if context.scope == "proactive_message":
            return await self._build_proactive_injection(context)

        reference = await self._resolve_reference(context.text, context)
        if reference is None:
            return ""

        try:
            summary_payload = await self._get_or_create_summary(context, reference)
        except Exception as exc:
            logger.error("Bilibili extension failed to build prompt injection: %s", exc, exc_info=True)
            return ""

        return (
            "A Bilibili video was detected in this conversation.\n"
            f"Video: {summary_payload['title']}\n"
            f"URL: {summary_payload['canonical_url']}\n"
            f"Source: {summary_payload['source_kind']}\n"
            f"Summary:\n{summary_payload['summary']}"
        )

    async def on_scheduled_trigger(self, trigger, context: ExtensionRuntimeContext) -> None:
        if trigger.name != "bilibili_cache_maintenance":
            return
        await context.storage.delete_records(
            context.extension_id,
            record_type=self._SUMMARY_RECORD_TYPE,
            only_expired=True,
        )

    async def _build_proactive_injection(self, context: ExtensionRuntimeContext) -> str:
        recent_hours = await self._get_int_setting(
            context,
            "proactive_recent_hours",
            default=6,
            minimum=1,
            maximum=72,
        )
        latest = await context.storage.get_latest_record(
            context.extension_id,
            record_type=self._SUMMARY_RECORD_TYPE,
            since_hours=recent_hours,
        )
        if latest is None or not latest.content.strip():
            return ""

        metadata = latest.metadata if isinstance(latest.metadata, dict) else {}
        title = str(metadata.get("title") or latest.title or "Bilibili summary").strip()
        canonical_url = str(metadata.get("canonical_url") or "").strip()
        lines = [
            f"Recent Bilibili context from the last {recent_hours} hours:",
            f"Title: {title}",
        ]
        if canonical_url:
            lines.append(f"URL: {canonical_url}")
        lines.append(f"Summary:\n{latest.content}")
        return "\n".join(lines)

    async def _resolve_reference(
        self,
        text: str,
        context: ExtensionRuntimeContext,
    ) -> BilibiliVideoReference | None:
        async with BilibiliClient(await self._get_sessdata(context)) as client:
            return await client.resolve_video_reference(text)

    async def _get_or_create_summary(
        self,
        context: ExtensionRuntimeContext,
        reference: BilibiliVideoReference,
        *,
        force_refresh: bool = False,
    ) -> dict[str, Any]:
        if not force_refresh:
            cached = await context.storage.get_record(
                context.extension_id,
                record_type=self._SUMMARY_RECORD_TYPE,
                record_key=reference.cache_key,
            )
            if cached and cached.content.strip():
                metadata = cached.metadata if isinstance(cached.metadata, dict) else {}
                return {
                    "bvid": str(metadata.get("bvid") or reference.bvid or "").strip(),
                    "aid": metadata.get("aid") or reference.aid,
                    "title": str(metadata.get("title") or cached.title or "").strip(),
                    "canonical_url": str(
                        metadata.get("canonical_url") or reference.canonical_url or reference.source_url
                    ).strip(),
                    "source_kind": str(metadata.get("source_kind") or "cache").strip(),
                    "summary": cached.content.strip(),
                    "cache_hit": True,
                }

        async with BilibiliClient(await self._get_sessdata(context)) as client:
            video = await client.fetch_video_context(reference)
            try:
                subtitle = await client.fetch_preferred_subtitle(video)
            except Exception as exc:
                logger.warning(
                    "Bilibili subtitle fetch failed for %s; falling back to video summary: %s",
                    video.bvid or f"av{video.aid}",
                    exc,
                )
                subtitle = None

            summary_text = ""
            source_kind = "cc_subtitle"
            subtitle_language = ""
            if subtitle and subtitle.text.strip():
                raw_text = "\n\n".join(
                    [
                        f"Title: {video.title}",
                        f"Uploader: {video.owner_name}",
                        f"URL: {video.canonical_url}",
                        f"Description: {video.description}",
                        f"Subtitle language: {subtitle.language or subtitle.language_label}",
                        f"Subtitle transcript:\n{subtitle.text}",
                    ]
                )
                subtitle_language = subtitle.language or subtitle.language_label
                summary_text = await context.summary.summarize(
                    raw_text,
                    focus="保留视频主题、主要观点、提到的人名或产品、可执行信息、关键链接。",
                    prompt_override=(
                        "请把下面的 Bilibili 视频元数据和中文字幕清洗成一段简洁的中文摘要。"
                        "摘要会被注入回本轮提示词，也会写入 Extension 数据库。"
                        "优先保留核心主题、主要观点、作者身份、关键结论和可执行信息。"
                    ),
                    max_input_chars=18000,
                    max_tokens=900,
                )
                if not summary_text.strip():
                    summary_text = raw_text[:1600].strip()
            else:
                source_kind = "video_fallback"
                video_path = await client.download_low_quality_video(
                    video,
                    max_bytes=await self._get_video_size_limit(context),
                )
                try:
                    multimodal_summary = await context.media.summarize_video(
                        file_path=video_path,
                        prompt_override=(
                            "请结合抽帧画面和音频，概括这个 Bilibili 视频在讲什么。"
                            "重点保留视频主题、说话人的主要观点、画面文字、关键步骤和可执行信息。"
                            "用中文输出纯文本摘要。"
                        ),
                        max_tokens=1000,
                    )
                    summary_text = await context.summary.clean_text(
                        multimodal_summary,
                        focus="把多模态摘要整理成适合主模型消费和数据库存储的中文摘要。",
                        prompt_override=(
                            "请把下面的多模态视频分析结果整理成一段紧凑、可信的中文摘要。"
                            "去掉重复句和噪声，只保留视频主题、主要观点、关键画面信息和可执行信息。"
                        ),
                        max_input_chars=12000,
                        max_tokens=900,
                    )
                    if not summary_text.strip():
                        summary_text = (multimodal_summary or "").strip()
                finally:
                    try:
                        Path(video_path).unlink(missing_ok=True)
                    except OSError:
                        pass

        summary_text = summary_text.strip()
        if not summary_text:
            raise BilibiliApiError("Generated an empty summary for the Bilibili video.")

        cache_hours = await self._get_int_setting(
            context,
            "summary_cache_hours",
            default=24,
            minimum=1,
            maximum=168,
        )
        metadata = {
            "bvid": video.bvid,
            "aid": video.aid,
            "title": video.title,
            "canonical_url": video.canonical_url,
            "source_kind": source_kind,
            "subtitle_language": subtitle_language,
        }
        await context.storage.put_record(
            context.extension_id,
            self._SUMMARY_RECORD_TYPE,
            summary_text,
            record_key=reference.cache_key,
            title=video.title,
            metadata=metadata,
            expires_at=get_utc_now() + timedelta(hours=cache_hours),
        )
        return {
            "bvid": video.bvid,
            "aid": video.aid,
            "title": video.title,
            "canonical_url": video.canonical_url,
            "source_kind": source_kind,
            "summary": summary_text,
            "cache_hit": False,
        }

    async def _get_sessdata(self, context: ExtensionRuntimeContext) -> str:
        value = await context.storage.get_setting(context.extension_id, "sessdata", default="")
        return str(value or "").strip()

    async def _get_video_size_limit(self, context: ExtensionRuntimeContext) -> int:
        max_megabytes = await self._get_int_setting(
            context,
            "video_max_megabytes",
            default=48,
            minimum=8,
            maximum=256,
        )
        return max_megabytes * 1024 * 1024

    async def _get_int_setting(
        self,
        context: ExtensionRuntimeContext,
        key: str,
        *,
        default: int,
        minimum: int,
        maximum: int,
    ) -> int:
        raw_value = await context.storage.get_setting(context.extension_id, key, default=str(default))
        try:
            value = int(str(raw_value).strip() or default)
        except (TypeError, ValueError):
            value = default
        return max(minimum, min(maximum, value))
