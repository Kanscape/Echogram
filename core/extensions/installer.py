from __future__ import annotations

import asyncio
import io
import json
import shutil
import tempfile
import zipfile
from pathlib import Path
from typing import Any

from config.settings import settings
from utils.logger import logger

from .manifest import ExtensionManifest


class ExtensionInstallError(Exception):
    pass


class ExtensionInstaller:
    def __init__(self, root_dir: str | None = None):
        self._root_dir = Path(root_dir or settings.EXTENSIONS_DIR)

    async def install(self, payload: dict[str, Any]) -> dict[str, Any]:
        method = str(payload.get("method") or "").strip().lower()
        overwrite = self._as_bool(payload.get("overwrite"))

        if method == "git_url":
            url = str(payload.get("url") or "").strip()
            return await self.install_from_git_url(url, overwrite=overwrite)

        raise ExtensionInstallError(f"Unsupported install method: {method or 'unknown'}")

    async def install_from_git_url(self, url: str, *, overwrite: bool = False) -> dict[str, Any]:
        if not url:
            raise ExtensionInstallError("Repository URL is required.")

        self._root_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory(prefix="echogram-ext-git-") as tmpdir:
            repo_dir = Path(tmpdir) / "repo"
            try:
                proc = await asyncio.create_subprocess_exec(
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    url,
                    str(repo_dir),
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
            except FileNotFoundError as exc:
                raise ExtensionInstallError("Git is not installed or not available in PATH.") from exc
            stdout, stderr = await proc.communicate()
            if proc.returncode != 0:
                stderr_text = (stderr or b"").decode("utf-8", errors="replace").strip()
                stdout_text = (stdout or b"").decode("utf-8", errors="replace").strip()
                message = stderr_text or stdout_text or "git clone failed"
                raise ExtensionInstallError(message)

            source_dir = self._locate_extension_root(repo_dir)
            return self._finalize_install(
                source_dir,
                source_type="git_url",
                overwrite=overwrite,
            )

    async def install_from_zip_bytes(
        self,
        filename: str,
        raw_bytes: bytes,
        *,
        overwrite: bool = False,
    ) -> dict[str, Any]:
        if not raw_bytes:
            raise ExtensionInstallError("ZIP payload is empty.")

        self._root_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory(prefix="echogram-ext-zip-") as tmpdir:
            extract_dir = Path(tmpdir) / "unzipped"
            extract_dir.mkdir(parents=True, exist_ok=True)

            try:
                with zipfile.ZipFile(io.BytesIO(raw_bytes)) as archive:
                    self._validate_zip_members(archive)
                    archive.extractall(extract_dir)
            except zipfile.BadZipFile as exc:
                raise ExtensionInstallError(f"Invalid ZIP archive: {filename or 'upload.zip'}") from exc

            source_dir = self._locate_extension_root(extract_dir)
            return self._finalize_install(
                source_dir,
                source_type="local_zip",
                overwrite=overwrite,
            )

    def _finalize_install(
        self,
        source_dir: Path,
        *,
        source_type: str,
        overwrite: bool,
    ) -> dict[str, Any]:
        manifest_path = source_dir / "manifest.json"
        payload = self._read_manifest_payload(manifest_path)
        normalized_payload = dict(payload)
        normalized_payload["source_type"] = source_type
        normalized_payload["status"] = "installed"
        normalized_payload["installed"] = True
        normalized_payload.setdefault("enabled", False)

        manifest = ExtensionManifest.from_dict(
            normalized_payload,
            local_path=str(source_dir.resolve()),
            source_type=source_type,
        )
        self._validate_manifest(manifest)

        destination_dir = self._root_dir / manifest.id
        if destination_dir.exists():
            if not overwrite:
                raise ExtensionInstallError(
                    f"Extension '{manifest.id}' already exists. Set overwrite=true to replace it."
                )
            shutil.rmtree(destination_dir)

        shutil.copytree(source_dir, destination_dir)
        destination_manifest_path = destination_dir / "manifest.json"
        destination_manifest_path.write_text(
            json.dumps(normalized_payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        installed_manifest = ExtensionManifest.from_dict(
            normalized_payload,
            local_path=str(destination_dir.resolve()),
            source_type=source_type,
        )

        logger.info("Installed extension %s from %s", installed_manifest.id, source_type)
        return {
            "ok": True,
            "method": source_type,
            "message": f"Installed extension '{installed_manifest.id}'.",
            "extension": installed_manifest.to_dict(),
        }

    def _locate_extension_root(self, root: Path) -> Path:
        direct_manifest = root / "manifest.json"
        if direct_manifest.exists():
            return root

        candidates = [
            child
            for child in root.iterdir()
            if child.is_dir() and not child.name.startswith(".") and (child / "manifest.json").exists()
        ]
        if len(candidates) == 1:
            return candidates[0]

        raise ExtensionInstallError(
            "Could not locate manifest.json. Expected it at archive/repository root or one level below."
        )

    def _read_manifest_payload(self, manifest_path: Path) -> dict[str, Any]:
        if not manifest_path.exists():
            raise ExtensionInstallError("manifest.json not found.")

        try:
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ExtensionInstallError(f"Invalid manifest.json: {exc}") from exc

        if not isinstance(payload, dict):
            raise ExtensionInstallError("manifest.json must contain a JSON object.")

        return payload

    def _validate_manifest(self, manifest: ExtensionManifest):
        if not manifest.id:
            raise ExtensionInstallError("Manifest field 'id' is required.")
        if not manifest.name:
            raise ExtensionInstallError("Manifest field 'name' is required.")
        if not manifest.purpose:
            raise ExtensionInstallError("Manifest field 'purpose' is required.")

    def _validate_zip_members(self, archive: zipfile.ZipFile):
        for member in archive.infolist():
            member_path = Path(member.filename)
            if member_path.is_absolute():
                raise ExtensionInstallError("ZIP archive contains an absolute path.")
            if any(part == ".." for part in member_path.parts):
                raise ExtensionInstallError("ZIP archive contains a parent path traversal entry.")

    def _as_bool(self, value: Any) -> bool:
        if isinstance(value, bool):
            return value
        return str(value).strip().lower() in {"1", "true", "yes", "on"}


extension_installer = ExtensionInstaller()
