from __future__ import annotations

import base64
import os
import subprocess
import tempfile
from pathlib import Path

from openai import AsyncOpenAI

from config.settings import settings
from core.config_service import config_service
from core.media_service import MediaServiceError, media_service
from utils.config_validator import safe_float_config

from .manifest import ExtensionManifest


class ExtensionMediaHelper:
    _PERMISSION = "llm:multimodal"
    _SYSTEM_PROMPT = (
        "You are a safe multimodal analysis utility for Echogram extensions. "
        "Turn images, audio, and sampled video inputs into a faithful plain-text summary. "
        "Keep concrete facts, entities, actions, timestamps, links, and visible text when useful. "
        "Output plain text only."
    )
    _DEFAULT_IMAGE_PROMPT = (
        "Summarize the image in plain text. Focus on the main subject, visible text, important UI, "
        "and actionable details."
    )
    _DEFAULT_AUDIO_PROMPT = (
        "Summarize the audio content in plain text. Focus on spoken facts, topics, named entities, "
        "and actionable details."
    )
    _DEFAULT_VIDEO_PROMPT = (
        "Summarize the video in plain text using the sampled frames and extracted audio. "
        "Focus on the main topic, important scenes, speaker claims, visible text, and actionable details."
    )
    _MAX_FRAME_COUNT = 6

    def __init__(self, manifest: ExtensionManifest):
        self._manifest = manifest

    def _ensure_allowed(self) -> None:
        permissions = {permission.strip().lower() for permission in self._manifest.permissions if permission}
        if self._PERMISSION not in permissions:
            raise PermissionError(
                f"Extension '{self._manifest.id}' must declare permission '{self._PERMISSION}' "
                "before calling the multimodal helper."
            )

    async def _get_client_config(self, model_name: str | None = None) -> tuple[str, str | None, str]:
        configs = await config_service.get_all_settings()
        api_key = configs.get("api_key")
        base_url = configs.get("api_base_url")
        selected_model = (
            (model_name or "").strip()
            or (configs.get("media_model") or "").strip()
            or (configs.get("model_name") or "").strip()
            or settings.OPENAI_MODEL_NAME
            or "gpt-4o-mini"
        )
        if not api_key:
            raise MediaServiceError("API key is not configured.")
        return api_key, base_url, selected_model

    async def _run_prompt(
        self,
        *,
        prompt_text: str,
        content_items: list[dict],
        model_name: str | None = None,
        max_tokens: int = 900,
        temperature: float = 0.2,
    ) -> str:
        self._ensure_allowed()
        api_key, base_url, selected_model = await self._get_client_config(model_name=model_name)
        client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        response = await client.chat.completions.create(
            model=selected_model,
            messages=[
                {"role": "system", "content": self._SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [{"type": "text", "text": prompt_text}, *content_items],
                },
            ],
            temperature=safe_float_config(temperature, 0.2, 0.0, 1.5),
            max_tokens=max(64, min(int(max_tokens or 900), 2000)),
            modalities=["text"],
        )
        if response.choices and response.choices[0].message.content:
            return response.choices[0].message.content.strip()
        return ""

    async def summarize_image(
        self,
        file_bytes: bytes,
        *,
        prompt_override: str = "",
        model_name: str | None = None,
        max_tokens: int = 400,
        detail: str = "low",
    ) -> str:
        encoded_image = await media_service.process_image_to_base64(file_bytes)
        prompt_text = (prompt_override or "").strip() or self._DEFAULT_IMAGE_PROMPT
        return await self._run_prompt(
            prompt_text=prompt_text,
            content_items=[
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{encoded_image}",
                        "detail": detail if detail in {"low", "high", "auto"} else "low",
                    },
                }
            ],
            model_name=model_name,
            max_tokens=max_tokens,
        )

    async def summarize_audio(
        self,
        file_bytes: bytes,
        *,
        prompt_override: str = "",
        model_name: str | None = None,
        max_tokens: int = 700,
    ) -> str:
        encoded_audio = await media_service.process_audio_to_base64(file_bytes)
        if not encoded_audio:
            raise MediaServiceError("Audio preprocessing failed.")

        prompt_text = (prompt_override or "").strip() or self._DEFAULT_AUDIO_PROMPT
        return await self._run_prompt(
            prompt_text=prompt_text,
            content_items=[
                {
                    "type": "input_audio",
                    "input_audio": {
                        "data": encoded_audio,
                        "format": "wav",
                    },
                }
            ],
            model_name=model_name,
            max_tokens=max_tokens,
        )

    async def summarize_video(
        self,
        *,
        file_path: str | None = None,
        file_bytes: bytes | None = None,
        filename: str = "video.mp4",
        prompt_override: str = "",
        model_name: str | None = None,
        max_tokens: int = 900,
        frame_count: int = 4,
        max_audio_seconds: int = 180,
    ) -> str:
        temp_input_path: str | None = None
        source_path = file_path

        if not source_path and file_bytes is None:
            raise MediaServiceError("Either file_path or file_bytes is required.")

        if file_bytes is not None:
            suffix = Path(filename or "video.mp4").suffix or ".mp4"
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
                temp_file.write(file_bytes)
                temp_input_path = temp_file.name
            source_path = temp_input_path

        if not source_path or not os.path.exists(source_path):
            raise MediaServiceError("Video file does not exist.")

        try:
            frame_bytes_list, audio_wav_bytes, metadata = self._prepare_video_analysis_inputs(
                source_path,
                frame_count=frame_count,
                max_audio_seconds=max_audio_seconds,
            )

            if not frame_bytes_list and not audio_wav_bytes:
                raise MediaServiceError("Unable to extract usable frames or audio from the video.")

            content_items: list[dict] = []
            for frame_bytes in frame_bytes_list:
                encoded_frame = await media_service.process_image_to_base64(frame_bytes)
                content_items.append(
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{encoded_frame}",
                            "detail": "low",
                        },
                    }
                )

            if audio_wav_bytes:
                content_items.append(
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "data": base64.b64encode(audio_wav_bytes).decode("utf-8"),
                            "format": "wav",
                        },
                    }
                )

            metadata_lines = [
                f"Video source: {Path(source_path).name}",
                f"Sampled frames: {metadata.get('frame_count', 0)}",
            ]
            duration = metadata.get("duration_seconds")
            if isinstance(duration, (int, float)) and duration > 0:
                metadata_lines.append(f"Approx duration: {duration:.1f} seconds")
            if metadata.get("audio_trimmed"):
                metadata_lines.append(
                    f"Audio was trimmed to the first {int(metadata.get('audio_seconds', max_audio_seconds))} seconds."
                )

            prompt_text = (prompt_override or "").strip() or self._DEFAULT_VIDEO_PROMPT
            return await self._run_prompt(
                prompt_text=f"{prompt_text}\n\n" + "\n".join(metadata_lines),
                content_items=content_items,
                model_name=model_name,
                max_tokens=max_tokens,
            )
        finally:
            if temp_input_path and os.path.exists(temp_input_path):
                try:
                    os.remove(temp_input_path)
                except OSError:
                    pass

    def _prepare_video_analysis_inputs(
        self,
        file_path: str,
        *,
        frame_count: int,
        max_audio_seconds: int,
    ) -> tuple[list[bytes], bytes | None, dict]:
        safe_frame_count = max(1, min(int(frame_count or 4), self._MAX_FRAME_COUNT))
        safe_audio_seconds = max(15, min(int(max_audio_seconds or 180), 900))
        duration_seconds = self._probe_media_duration(file_path)
        sample_times = self._build_video_sample_times(duration_seconds, safe_frame_count)

        frame_bytes_list: list[bytes] = []
        audio_wav_bytes: bytes | None = None

        with tempfile.TemporaryDirectory(prefix="echogram-ext-video-") as temp_dir:
            for index, sample_time in enumerate(sample_times):
                frame_path = os.path.join(temp_dir, f"frame_{index}.jpg")
                frame_command = [
                    "ffmpeg",
                    "-y",
                    "-ss",
                    f"{sample_time:.3f}",
                    "-i",
                    file_path,
                    "-frames:v",
                    "1",
                    "-vf",
                    "scale=1280:-2:force_original_aspect_ratio=decrease",
                    frame_path,
                ]
                frame_result = subprocess.run(frame_command, capture_output=True, text=True, check=False)
                if frame_result.returncode == 0 and os.path.exists(frame_path):
                    frame_bytes_list.append(Path(frame_path).read_bytes())

            audio_path = os.path.join(temp_dir, "audio.wav")
            audio_command = [
                "ffmpeg",
                "-y",
                "-i",
                file_path,
                "-vn",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-t",
                str(safe_audio_seconds),
                audio_path,
            ]
            audio_result = subprocess.run(audio_command, capture_output=True, text=True, check=False)
            if audio_result.returncode == 0 and os.path.exists(audio_path):
                audio_wav_bytes = Path(audio_path).read_bytes()

        return (
            frame_bytes_list,
            audio_wav_bytes,
            {
                "duration_seconds": duration_seconds,
                "frame_count": len(frame_bytes_list),
                "audio_seconds": safe_audio_seconds,
                "audio_trimmed": bool(duration_seconds and duration_seconds > safe_audio_seconds),
            },
        )

    def _probe_media_duration(self, file_path: str) -> float | None:
        command = [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            file_path,
        ]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=False)
        except FileNotFoundError as exc:
            raise MediaServiceError("ffprobe is not available. Please ensure ffmpeg is installed.") from exc

        if result.returncode != 0:
            return None

        try:
            return max(0.0, float((result.stdout or "").strip()))
        except (TypeError, ValueError):
            return None

    def _build_video_sample_times(self, duration_seconds: float | None, frame_count: int) -> list[float]:
        if not duration_seconds or duration_seconds <= 0.1:
            return [0.0]

        return [
            max(0.0, duration_seconds * (index + 1) / (frame_count + 1))
            for index in range(frame_count)
        ]
