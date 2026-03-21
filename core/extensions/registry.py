from __future__ import annotations

import json
from pathlib import Path

from config.settings import settings
from utils.logger import logger

from .manifest import ExtensionImportMethod, ExtensionManifest
from .matcher import ExtensionEventContext, ExtensionTriggerMatcher


class ExtensionRegistry:
    def __init__(self, root_dir: str | None = None):
        self._root_dir = Path(root_dir or settings.EXTENSIONS_DIR)

    @property
    def root_dir(self) -> Path:
        return self._root_dir

    def list_extensions(self) -> list[ExtensionManifest]:
        manifests: list[ExtensionManifest] = []

        if not self._root_dir.exists():
            return manifests

        for candidate in sorted(self._root_dir.iterdir(), key=lambda item: item.name.lower()):
            if not candidate.is_dir():
                continue

            manifest_path = candidate / "manifest.json"
            if not manifest_path.exists():
                continue

            try:
                payload = json.loads(manifest_path.read_text(encoding="utf-8"))
                if not isinstance(payload, dict):
                    logger.warning("Extension manifest is not an object: %s", manifest_path)
                    continue
                manifests.append(
                    ExtensionManifest.from_dict(
                        payload,
                        local_path=str(candidate.resolve()),
                        source_type="local_dir",
                    )
                )
            except Exception as exc:
                logger.error("Failed to load extension manifest %s: %s", manifest_path, exc)

        return manifests

    def get_extension(self, extension_id: str) -> ExtensionManifest | None:
        normalized = (extension_id or "").strip().lower()
        if not normalized:
            return None

        for manifest in self.list_extensions():
            if manifest.id.lower() == normalized:
                return manifest
        return None

    def match_extensions(
        self,
        *,
        scope: str,
        text: str = "",
    ) -> list[tuple[ExtensionManifest, tuple]]:
        context = ExtensionEventContext.from_text(scope=scope, text=text)
        matches: list[tuple[ExtensionManifest, tuple]] = []

        for manifest in self.list_extensions():
            matched_triggers = ExtensionTriggerMatcher.match_manifest(manifest, context)
            if matched_triggers:
                matches.append((manifest, matched_triggers))

        return matches

    def get_import_methods(self) -> list[ExtensionImportMethod]:
        return [
            ExtensionImportMethod(
                id="index",
                label="Curated Index",
                description="Install from a curated registry/index repository.",
                recommended=True,
                enabled=bool(settings.EXTENSION_INDEX_URL),
            ),
            ExtensionImportMethod(
                id="git_url",
                label="Repository URL",
                description="Install from a Git repository URL for power-user workflows.",
            ),
            ExtensionImportMethod(
                id="local_zip",
                label="Local ZIP",
                description="Upload a local ZIP package for offline or private extensions.",
            ),
        ]

    def get_catalog(self) -> dict:
        return {
            "items": [manifest.to_dict() for manifest in self.list_extensions()],
            "import_methods": [method.to_dict() for method in self.get_import_methods()],
            "recommended_index_url": settings.EXTENSION_INDEX_URL or None,
            "extensions_dir": str(self._root_dir.resolve()),
        }


extension_registry = ExtensionRegistry()
