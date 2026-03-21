from __future__ import annotations

import re
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import httpx


_BVID_PATTERN = re.compile(r"\b(BV[0-9A-Za-z]{10})\b", flags=re.IGNORECASE)
_AID_PATTERN = re.compile(r"\bav(\d+)\b", flags=re.IGNORECASE)
_URL_PATTERN = re.compile(
    r"(?:(?:https?://)?(?:[a-zA-Z0-9-]+\.)?(?:bilibili\.com|b23\.tv)(?:/[^\s<>()]*)?)",
    flags=re.IGNORECASE,
)
_DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/123.0.0.0 Safari/537.36"
    ),
    "Referer": "https://www.bilibili.com/",
}
_LANGUAGE_PRIORITY = ("zh-CN", "zh-Hans", "ai-zh")


class BilibiliApiError(RuntimeError):
    pass


@dataclass(frozen=True)
class BilibiliVideoReference:
    bvid: str = ""
    aid: int | None = None
    source_url: str = ""
    canonical_url: str = ""

    @property
    def cache_key(self) -> str:
        if self.bvid:
            return self.bvid
        if self.aid is not None:
            return f"av{self.aid}"
        raise BilibiliApiError("Missing Bilibili video reference.")


@dataclass(frozen=True)
class BilibiliVideoContext:
    bvid: str
    aid: int
    cid: int
    title: str
    owner_name: str
    description: str
    canonical_url: str


@dataclass(frozen=True)
class BilibiliSubtitlePayload:
    language: str
    language_label: str
    subtitle_url: str
    text: str
    raw_json: dict


class BilibiliClient:
    def __init__(self, sessdata: str = ""):
        cookies = {}
        if (sessdata or "").strip():
            cookies["SESSDATA"] = sessdata.strip()
        self._client = httpx.AsyncClient(
            headers=dict(_DEFAULT_HEADERS),
            cookies=cookies,
            follow_redirects=True,
            timeout=30.0,
        )

    async def __aenter__(self) -> "BilibiliClient":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        await self.close()

    async def close(self) -> None:
        await self._client.aclose()

    async def resolve_video_reference(self, text: str) -> BilibiliVideoReference | None:
        raw_text = (text or "").strip()
        if not raw_text:
            return None

        for raw_url in _URL_PATTERN.findall(raw_text):
            normalized_url = self._normalize_url(raw_url)
            final_url = normalized_url
            if "b23.tv" in normalized_url.lower():
                try:
                    final_url = await self._resolve_short_url(normalized_url)
                except Exception:
                    final_url = normalized_url
            reference = self._extract_reference_from_text(final_url)
            if reference:
                return BilibiliVideoReference(
                    bvid=reference.bvid,
                    aid=reference.aid,
                    source_url=normalized_url,
                    canonical_url=final_url,
                )

        reference = self._extract_reference_from_text(raw_text)
        if reference:
            return BilibiliVideoReference(
                bvid=reference.bvid,
                aid=reference.aid,
                source_url="",
                canonical_url=reference.canonical_url,
            )
        return None

    async def fetch_video_context(self, reference: BilibiliVideoReference) -> BilibiliVideoContext:
        params: dict[str, str | int] = {}
        if reference.bvid:
            params["bvid"] = reference.bvid
        elif reference.aid is not None:
            params["aid"] = int(reference.aid)
        else:
            raise BilibiliApiError("Video reference must include bvid or aid.")

        response = await self._client.get("https://api.bilibili.com/x/web-interface/view", params=params)
        payload = response.json()
        data = self._unwrap_bilibili_payload(payload, "view")

        pages = data.get("pages") or []
        first_page = pages[0] if pages else {}
        cid = first_page.get("cid")
        if not cid:
            raise BilibiliApiError("Missing cid in Bilibili view response.")

        bvid = str(data.get("bvid") or reference.bvid or "").strip()
        aid = int(data.get("aid") or reference.aid or 0)
        canonical_url = f"https://www.bilibili.com/video/{bvid}" if bvid else reference.canonical_url
        return BilibiliVideoContext(
            bvid=bvid,
            aid=aid,
            cid=int(cid),
            title=str(data.get("title") or "").strip(),
            owner_name=str((data.get("owner") or {}).get("name") or "").strip(),
            description=str(data.get("desc") or "").strip(),
            canonical_url=canonical_url,
        )

    async def fetch_preferred_subtitle(
        self,
        video: BilibiliVideoContext,
    ) -> BilibiliSubtitlePayload | None:
        response = await self._client.get(
            "https://api.bilibili.com/x/player/v2",
            params={"aid": video.aid, "cid": video.cid},
        )
        payload = response.json()
        data = self._unwrap_bilibili_payload(payload, "player_v2")
        subtitle_block = (data.get("subtitle") or {}).get("subtitles") or []
        if not subtitle_block:
            return None

        preferred = self._pick_preferred_subtitle(subtitle_block)
        if preferred is None:
            return None

        subtitle_url = self._normalize_subtitle_url(str(preferred.get("subtitle_url") or "").strip())
        if not subtitle_url:
            return None

        subtitle_response = await self._client.get(subtitle_url)
        subtitle_response.raise_for_status()
        subtitle_json = subtitle_response.json()
        subtitle_text = self._subtitle_json_to_text(subtitle_json)
        if not subtitle_text:
            return None

        return BilibiliSubtitlePayload(
            language=str(preferred.get("lan") or "").strip(),
            language_label=str(preferred.get("lan_doc") or "").strip(),
            subtitle_url=subtitle_url,
            text=subtitle_text,
            raw_json=subtitle_json,
        )

    async def download_low_quality_video(
        self,
        video: BilibiliVideoContext,
        *,
        max_bytes: int = 48 * 1024 * 1024,
    ) -> str:
        response = await self._client.get(
            "https://api.bilibili.com/x/player/playurl",
            params={
                "avid": video.aid,
                "cid": video.cid,
                "qn": 16,
                "platform": "html5",
                "otype": "json",
                "fnval": 0,
            },
        )
        payload = response.json()
        data = self._unwrap_bilibili_payload(payload, "playurl")
        durl = data.get("durl") or []
        media_url = str((durl[0] or {}).get("url") or "").strip() if durl else ""
        if not media_url:
            raise BilibiliApiError("No downloadable MP4 URL was returned by Bilibili.")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_file:
            temp_path = temp_file.name

        total_bytes = 0
        stream_headers = dict(_DEFAULT_HEADERS)
        stream_headers["Referer"] = video.canonical_url or _DEFAULT_HEADERS["Referer"]
        try:
            async with self._client.stream("GET", media_url, headers=stream_headers) as media_response:
                media_response.raise_for_status()
                with open(temp_path, "wb") as output_file:
                    async for chunk in media_response.aiter_bytes(65536):
                        if not chunk:
                            continue
                        total_bytes += len(chunk)
                        if total_bytes > max_bytes:
                            raise BilibiliApiError(
                                f"Downloaded video exceeded the size limit ({max_bytes} bytes)."
                            )
                        output_file.write(chunk)
            return temp_path
        except Exception:
            try:
                Path(temp_path).unlink(missing_ok=True)
            except OSError:
                pass
            raise

    async def _resolve_short_url(self, url: str) -> str:
        response = await self._client.get(url)
        return str(response.url)

    def _extract_reference_from_text(self, text: str) -> BilibiliVideoReference | None:
        bvid_match = _BVID_PATTERN.search(text or "")
        if bvid_match:
            bvid = self._normalize_bvid(bvid_match.group(1))
            return BilibiliVideoReference(
                bvid=bvid,
                canonical_url=f"https://www.bilibili.com/video/{bvid}",
            )

        aid_match = _AID_PATTERN.search(text or "")
        if aid_match:
            aid = int(aid_match.group(1))
            return BilibiliVideoReference(
                aid=aid,
                canonical_url=f"https://www.bilibili.com/video/av{aid}",
            )

        parsed = urlparse(self._normalize_url(text))
        query = parse_qs(parsed.query)
        bvid = ((query.get("bvid") or [""])[0] or "").strip()
        if bvid:
            normalized_bvid = self._normalize_bvid(bvid)
            return BilibiliVideoReference(
                bvid=normalized_bvid,
                canonical_url=f"https://www.bilibili.com/video/{normalized_bvid}",
            )
        aid_text = ((query.get("aid") or query.get("avid") or [""])[0] or "").strip()
        if aid_text.isdigit():
            aid = int(aid_text)
            return BilibiliVideoReference(
                aid=aid,
                canonical_url=f"https://www.bilibili.com/video/av{aid}",
            )
        return None

    def _pick_preferred_subtitle(self, subtitles: list[dict]) -> dict | None:
        if not subtitles:
            return None

        normalized = []
        for item in subtitles:
            lan = str(item.get("lan") or "").strip()
            lan_doc = str(item.get("lan_doc") or "").strip()
            normalized.append((lan, lan_doc, item))

        for target in _LANGUAGE_PRIORITY:
            for lan, _, item in normalized:
                if lan.lower() == target.lower():
                    return item
        return normalized[0][2]

    def _subtitle_json_to_text(self, subtitle_json: dict) -> str:
        body = subtitle_json.get("body") or []
        lines: list[str] = []
        for item in body:
            content = str(item.get("content") or "").strip()
            if not content:
                continue
            start = self._format_seconds(item.get("from"))
            end = self._format_seconds(item.get("to"))
            if start or end:
                lines.append(f"[{start}-{end}] {content}")
            else:
                lines.append(content)
        return "\n".join(lines)

    def _unwrap_bilibili_payload(self, payload: dict, api_name: str) -> dict:
        code = payload.get("code", -1)
        if code != 0:
            message = str(payload.get("message") or payload.get("msg") or "Unknown error").strip()
            raise BilibiliApiError(f"Bilibili {api_name} failed with code {code}: {message}")
        data = payload.get("data")
        if not isinstance(data, dict):
            raise BilibiliApiError(f"Bilibili {api_name} returned an unexpected payload.")
        return data

    def _normalize_url(self, url: str) -> str:
        normalized = (url or "").strip()
        if normalized and "://" not in normalized:
            normalized = f"https://{normalized}"
        return normalized

    def _normalize_subtitle_url(self, url: str) -> str:
        normalized = (url or "").strip()
        if normalized.startswith("//"):
            return f"https:{normalized}"
        return normalized

    def _normalize_bvid(self, value: str) -> str:
        text = (value or "").strip()
        if len(text) >= 2 and text[:2].lower() == "bv":
            return f"BV{text[2:]}"
        return text

    def _format_seconds(self, value: object) -> str:
        try:
            seconds = max(0.0, float(value))
        except (TypeError, ValueError):
            return ""
        minutes = int(seconds // 60)
        remaining = seconds - minutes * 60
        return f"{minutes:02d}:{remaining:05.2f}"
