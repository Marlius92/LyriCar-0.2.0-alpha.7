from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

from lyricar_core import LyricsDocument, LyricLine, Track, document_from_json, document_to_json, parse_lrc, similarity


class LRCLibError(RuntimeError):
    pass


@dataclass
class CacheEnvelope:
    stored_at: float
    miss: bool
    document: dict | None


class LRCLibClient:
    def __init__(self, cache_directory: Path | None = None) -> None:
        if cache_directory is None:
            root = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".cache"))
            cache_directory = root / "LyriCar" / "lyrics"
        self.cache_directory = cache_directory
        self.cache_directory.mkdir(parents=True, exist_ok=True)
        self.hit_ttl = 30 * 24 * 3600
        self.miss_ttl = 24 * 3600
        self.user_agent = "LyriCar-WindowsPreview/0.1 (personal client)"

    def get_lyrics(self, track: Track, force_refresh: bool = False) -> LyricsDocument | None:
        if not force_refresh:
            cached = self._read_cache(track)
            if cached is not ...:
                return cached

        payload = self._request_json(
            "/api/get",
            {
                "track_name": track.title,
                "artist_name": track.primary_artist,
                "album_name": track.album,
                "duration": round(track.duration),
            },
            allow_not_found=True,
        )
        document = self._payload_to_document(payload) if isinstance(payload, dict) else None

        if document is None:
            results = self._request_json(
                "/api/search",
                {
                    "track_name": track.title,
                    "artist_name": track.primary_artist,
                    "album_name": track.album,
                },
            )
            if isinstance(results, list):
                results.sort(key=lambda item: self._score(item, track), reverse=True)
                for item in results[:8]:
                    document = self._payload_to_document(item)
                    if document is not None:
                        break

        self._write_cache(track, document)
        return document

    def clear_cache(self) -> None:
        for path in self.cache_directory.glob("*.json"):
            try:
                path.unlink()
            except OSError:
                pass

    def _request_json(self, path: str, params: dict, allow_not_found: bool = False):
        filtered = {key: value for key, value in params.items() if value not in (None, "")}
        query = urllib.parse.urlencode(filtered)
        url = f"https://lrclib.net{path}?{query}"
        request = urllib.request.Request(
            url,
            headers={"Accept": "application/json", "Lrclib-Client": self.user_agent},
        )
        last_error: Exception | None = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=20) as response:
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if exc.code == 404 and allow_not_found:
                    return None
                if exc.code == 429 or 500 <= exc.code <= 599:
                    last_error = exc
                    time.sleep(0.4 * (2**attempt))
                    continue
                raise LRCLibError(f"LRCLIB HTTP {exc.code}") from exc
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                last_error = exc
                time.sleep(0.4 * (2**attempt))
        raise LRCLibError(f"LRCLIB non disponibile: {last_error}")

    def _payload_to_document(self, payload: dict | None) -> LyricsDocument | None:
        if not payload:
            return None
        if payload.get("instrumental"):
            return LyricsDocument(
                track_title=payload.get("trackName") or payload.get("name") or "",
                artist_name=payload.get("artistName") or "",
                album_name=payload.get("albumName"),
                duration=float(payload.get("duration") or 0),
                lines=[],
                provider="lrclib",
                provider_id=payload.get("id"),
                instrumental=True,
                plain_lyrics=payload.get("plainLyrics"),
            )
        synced = payload.get("syncedLyrics")
        if not synced:
            return None
        try:
            lines, _, _ = parse_lrc(synced)
        except ValueError:
            return None
        return LyricsDocument(
            track_title=payload.get("trackName") or payload.get("name") or "",
            artist_name=payload.get("artistName") or "",
            album_name=payload.get("albumName"),
            duration=float(payload.get("duration") or (lines[-1].timestamp + 5)),
            lines=lines,
            provider="lrclib",
            provider_id=payload.get("id"),
            instrumental=False,
            plain_lyrics=payload.get("plainLyrics"),
        )

    @staticmethod
    def _score(payload: dict, track: Track) -> float:
        title = similarity(payload.get("trackName") or payload.get("name") or "", track.title)
        artist = similarity(payload.get("artistName") or "", track.primary_artist)
        album = similarity(payload.get("albumName") or "", track.album or "") if track.album else 0.5
        candidate_duration = float(payload.get("duration") or 0)
        duration = max(0.0, 1.0 - abs(candidate_duration - track.duration) / 12.0) if track.duration else 0.5
        return title * 0.48 + artist * 0.30 + album * 0.08 + duration * 0.14

    def _cache_path(self, track: Track) -> Path:
        digest = hashlib.sha256(track.cache_key.encode("utf-8")).hexdigest()
        return self.cache_directory / f"{digest}.json"

    def _read_cache(self, track: Track):
        path = self._cache_path(track)
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            age = time.time() - float(data["stored_at"])
            ttl = self.miss_ttl if data.get("miss") else self.hit_ttl
            if age > ttl:
                path.unlink(missing_ok=True)
                return ...
            if data.get("miss"):
                return None
            return document_from_json(data["document"])
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
            return ...

    def _write_cache(self, track: Track, document: LyricsDocument | None) -> None:
        envelope = {
            "stored_at": time.time(),
            "miss": document is None,
            "document": document_to_json(document) if document else None,
        }
        try:
            self._cache_path(track).write_text(
                json.dumps(envelope, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        except OSError:
            pass
