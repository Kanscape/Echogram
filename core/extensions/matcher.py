from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Iterable
from urllib.parse import urlparse

from .manifest import ExtensionManifest, ExtensionTriggerManifest

_URL_PATTERN = re.compile(
    r"(?:(?:https?://)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:/[^\s<>()]*)?)",
    flags=re.IGNORECASE,
)


@dataclass(frozen=True)
class ExtensionEventContext:
    scope: str
    text: str = ""
    urls: tuple[str, ...] = field(default_factory=tuple)

    @classmethod
    def from_text(cls, *, scope: str, text: str = "") -> "ExtensionEventContext":
        return cls(
            scope=scope,
            text=text or "",
            urls=tuple(_extract_urls(text or "")),
        )


class ExtensionTriggerMatcher:
    @classmethod
    def match_manifest(
        cls,
        manifest: ExtensionManifest,
        context: ExtensionEventContext,
    ) -> tuple[ExtensionTriggerManifest, ...]:
        matched: list[ExtensionTriggerManifest] = []

        for trigger in manifest.triggers:
            if cls._matches_trigger(trigger, context):
                matched.append(trigger)

        return tuple(matched)

    @classmethod
    def _matches_trigger(
        cls,
        trigger: ExtensionTriggerManifest,
        context: ExtensionEventContext,
    ) -> bool:
        if not trigger.is_passive:
            return False

        if trigger.trigger_type == "scoped_passive":
            allowed_scopes = {scope.strip().lower() for scope in trigger.scopes if scope}
            if allowed_scopes and context.scope.strip().lower() not in allowed_scopes:
                return False

        if trigger.match.is_empty:
            return True

        return (
            cls._match_url_domains(trigger.match.url_domains, context.urls)
            or cls._match_keywords(trigger.match.keywords, context.text)
            or cls._match_regex(trigger.match.regex_patterns, context.text)
        )

    @staticmethod
    def _match_url_domains(domains: Iterable[str], urls: Iterable[str]) -> bool:
        normalized_domains = [domain.strip().lower() for domain in domains if domain and domain.strip()]
        if not normalized_domains:
            return False

        for url in urls:
            parsed = urlparse(url if "://" in url else f"https://{url}")
            hostname = (parsed.hostname or "").lower()
            if not hostname:
                continue
            for domain in normalized_domains:
                if hostname == domain or hostname.endswith(f".{domain}"):
                    return True
        return False

    @staticmethod
    def _match_keywords(keywords: Iterable[str], text: str) -> bool:
        haystack = (text or "").lower()
        if not haystack:
            return False

        for keyword in keywords:
            needle = (keyword or "").strip().lower()
            if needle and needle in haystack:
                return True
        return False

    @staticmethod
    def _match_regex(patterns: Iterable[str], text: str) -> bool:
        if not text:
            return False

        for pattern in patterns:
            raw_pattern = (pattern or "").strip()
            if not raw_pattern:
                continue
            try:
                if re.search(raw_pattern, text, flags=re.IGNORECASE):
                    return True
            except re.error:
                continue
        return False


def _extract_urls(text: str) -> list[str]:
    if not text:
        return []
    return [match.group(0) for match in _URL_PATTERN.finditer(text)]
