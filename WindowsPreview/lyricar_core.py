"""Core logic for the LyriCar Windows preview.

The shipping iOS app uses the Swift implementation under Sources/LyriCarCore.
This Python implementation mirrors the same behavior so layout and end-to-end
Spotify/LRCLIB tests can run on Windows without a Mac or a car.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import json
import math
import re
import time
from typing import Iterable, Optional

_TIMESTAMP_RE = re.compile(r"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]")
_HOUR_TIMESTAMP_RE = re.compile(r"\[(\d{1,2}):(\d{2}):(\d{2})(?:[\.:](\d{1,3}))?\]")
_METADATA_RE = re.compile(r"^\[([A-Za-z]+):\s*(.*?)\]\s*$")
_ENHANCED_RE = re.compile(r"<\d{1,3}:\d{2}(?:[\.:]\d{1,3})?>")


@dataclass(frozen=True)
class LyricLine:
    index: int
    timestamp: float
    text: str


@dataclass
class LyricsDocument:
    track_title: str
    artist_name: str
    duration: float
    lines: list[LyricLine]
    album_name: str | None = None
    provider: str = "local"
    provider_id: int | None = None
    instrumental: bool = False
    plain_lyrics: str | None = None


@dataclass
class Track:
    title: str
    artists: list[str]
    duration: float
    track_id: str | None = None
    album: str | None = None
    artwork_url: str | None = None

    @property
    def primary_artist(self) -> str:
        return self.artists[0] if self.artists else ""

    @property
    def display_artist(self) -> str:
        return ", ".join(self.artists)

    @property
    def cache_key(self) -> str:
        if self.track_id:
            return f"spotify:{self.track_id}"
        return "|".join(
            [self.title, self.display_artist, self.album or "", str(round(self.duration))]
        ).lower()


@dataclass
class PlaybackState:
    track: Track
    position: float
    is_playing: bool
    captured_monotonic: float = field(default_factory=time.monotonic)

    def estimated_position(self, now: float | None = None) -> float:
        now = time.monotonic() if now is None else now
        position = self.position
        if self.is_playing:
            position += max(0.0, now - self.captured_monotonic)
        return min(max(0.0, position), max(0.0, self.track.duration))


class PlaybackReconciler:
    """Turn coarse media-session samples into one continuous playback clock.

    Windows GSMTC often exposes a position that advances in relatively large
    steps.  Rendering that raw value at 60 FPS and replacing the local clock on
    every poll produces the visible pattern ``advance -> jump backwards ->
    advance``.  The reconciler keeps the locally interpolated clock monotonic
    while still recognising real seeks, track changes and pause/resume events.

    The class is deliberately independent from Tkinter and from Spotify so the
    same policy can be tested in isolation and reused by other preview sources.
    """

    def __init__(
        self,
        *,
        seek_threshold: float = 1.75,
        paused_seek_threshold: float = 0.15,
        maximum_forward_nudge: float = 0.20,
        forward_nudge_ratio: float = 0.35,
        stale_event_tolerance: float = 0.05,
    ) -> None:
        self.seek_threshold = max(0.25, float(seek_threshold))
        self.paused_seek_threshold = max(0.01, float(paused_seek_threshold))
        self.maximum_forward_nudge = max(0.0, float(maximum_forward_nudge))
        self.forward_nudge_ratio = min(max(float(forward_nudge_ratio), 0.0), 1.0)
        self.stale_event_tolerance = max(0.0, float(stale_event_tolerance))
        self._source: PlaybackState | None = None
        self._output: PlaybackState | None = None

    def reset(self) -> None:
        self._source = None
        self._output = None

    @property
    def output(self) -> PlaybackState | None:
        return self._output

    def apply(
        self,
        incoming: PlaybackState | None,
        *,
        now: float | None = None,
    ) -> PlaybackState | None:
        now = time.monotonic() if now is None else float(now)
        if incoming is None:
            self.reset()
            return None

        if (
            self._source is None
            or self._output is None
            or self._source.track.cache_key != incoming.track.cache_key
        ):
            return self._anchor(incoming, incoming.estimated_position(now), now)

        previous_source = self._source
        previous_output = self._output

        # A control command and the normal polling loop can occasionally return
        # out of order.  Never let an older sample overwrite a newer clock.
        if (
            incoming.captured_monotonic
            < previous_source.captured_monotonic - self.stale_event_tolerance
        ):
            return previous_output

        source_elapsed = max(
            0.0,
            incoming.captured_monotonic - previous_source.captured_monotonic,
        )
        raw_delta = incoming.position - previous_source.position
        expected_forward = source_elapsed if previous_source.is_playing else 0.0

        backward_seek = raw_delta < -self.seek_threshold
        forward_seek = raw_delta > expected_forward + self.seek_threshold
        paused_seek = (
            not previous_source.is_playing
            and not incoming.is_playing
            and abs(raw_delta) >= self.paused_seek_threshold
        )
        is_seek = backward_seek or forward_seek or paused_seek

        display_now = previous_output.estimated_position(now)
        source_now = incoming.estimated_position(now)

        if is_seek:
            output_position = source_now
        elif incoming.is_playing:
            # Ignore small backwards errors: they are normally a quantised or
            # stale GSMTC sample.  If the source is slightly ahead, converge
            # gently without an obvious jump in the progress bar or lyrics.
            positive_error = source_now - display_now
            if positive_error > 0.0:
                correction = min(
                    self.maximum_forward_nudge,
                    positive_error * self.forward_nudge_ratio,
                )
                output_position = display_now + correction
            else:
                output_position = display_now
        elif previous_output.is_playing:
            # On pause, the last raw sample can lag behind by almost a second.
            # Freeze the continuous clock unless the source is actually ahead.
            output_position = max(display_now, source_now)
        else:
            # While already paused, a changed source position represents a real
            # scrub/seek and should be shown immediately.  Otherwise hold still.
            output_position = source_now if paused_seek else display_now

        return self._anchor(incoming, output_position, now)

    def _anchor(
        self,
        source: PlaybackState,
        output_position: float,
        now: float,
    ) -> PlaybackState:
        duration = max(0.0, source.track.duration)
        anchored = PlaybackState(
            track=source.track,
            position=min(max(0.0, output_position), duration),
            is_playing=source.is_playing,
            captured_monotonic=now,
        )
        self._source = source
        self._output = anchored
        return anchored


@dataclass(frozen=True)
class LyricFrame:
    current_index: int | None
    previous2: LyricLine | None
    previous1: LyricLine | None
    current: LyricLine | None
    next1: LyricLine | None
    next2: LyricLine | None
    line_progress: float
    transition_progress: float
    karaoke_eligible: bool = False


EMPTY_FRAME = LyricFrame(None, None, None, None, None, None, 0.0, 0.0, False)


def _fraction(digits: str | None) -> float:
    if not digits:
        return 0.0
    return int(digits) / (10 ** len(digits))


def parse_lrc(source: str) -> tuple[list[LyricLine], dict[str, str], float]:
    metadata: dict[str, str] = {}
    raw: list[tuple[float, str]] = []

    for original in source.splitlines():
        line = original.strip()
        if not line:
            continue
        metadata_match = _METADATA_RE.fullmatch(line)
        if metadata_match:
            metadata[metadata_match.group(1).lower()] = metadata_match.group(2).strip()
            continue

        hour_matches = list(_HOUR_TIMESTAMP_RE.finditer(line))
        occupied = [(m.start(), m.end()) for m in hour_matches]
        standard_matches = [
            match
            for match in _TIMESTAMP_RE.finditer(line)
            if not any(match.start() < end and match.end() > start for start, end in occupied)
        ]
        matches = hour_matches + standard_matches
        if not matches:
            continue

        lyric_text = line
        for match in sorted(matches, key=lambda item: item.start(), reverse=True):
            lyric_text = lyric_text[: match.start()] + lyric_text[match.end() :]
        lyric_text = _ENHANCED_RE.sub("", lyric_text).strip()

        hour_ids = {id(match) for match in hour_matches}
        for match in matches:
            if id(match) in hour_ids:
                timestamp = (
                    int(match.group(1)) * 3600
                    + int(match.group(2)) * 60
                    + int(match.group(3))
                    + _fraction(match.group(4))
                )
            else:
                timestamp = (
                    int(match.group(1)) * 60
                    + int(match.group(2))
                    + _fraction(match.group(3))
                )
            raw.append((timestamp, lyric_text))

    offset = float(metadata.get("offset", "0") or 0) / 1000.0
    deduplicated: dict[int, tuple[float, str]] = {}
    for timestamp, text in raw:
        adjusted = max(0.0, timestamp + offset)
        key = round(adjusted * 1000)
        existing = deduplicated.get(key)
        if existing is None or (not existing[1] and text):
            deduplicated[key] = (adjusted, text)

    values = sorted(deduplicated.values(), key=lambda item: (item[0], item[1]))
    if not values:
        raise ValueError("No timed lyric lines were found")
    lines = [LyricLine(index=i, timestamp=item[0], text=item[1]) for i, item in enumerate(values)]
    return lines, metadata, offset


def parse_lrc_file(path: str | Path) -> LyricsDocument:
    file_path = Path(path)
    lines, metadata, _ = parse_lrc(file_path.read_text(encoding="utf-8-sig"))
    duration = max(lines[-1].timestamp + 5.0, 1.0)
    return LyricsDocument(
        track_title=metadata.get("ti", file_path.stem),
        artist_name=metadata.get("ar", "LyriCar Preview"),
        album_name=metadata.get("al"),
        duration=duration,
        lines=lines,
    )


def build_frame(
    document: LyricsDocument | None,
    playback_position: float,
    user_offset: float = 0.0,
    transition_window: float = 0.55,
) -> LyricFrame:
    if not document or not document.lines:
        return EMPTY_FRAME
    lines = document.lines
    effective = max(0.0, playback_position - user_offset)
    if effective < lines[0].timestamp:
        return LyricFrame(
            None,
            None,
            None,
            None,
            lines[0] if lines else None,
            lines[1] if len(lines) > 1 else None,
            0.0,
            0.0,
        )

    low, high, result = 0, len(lines) - 1, 0
    while low <= high:
        middle = low + (high - low) // 2
        if lines[middle].timestamp <= effective:
            result = middle
            low = middle + 1
        else:
            high = middle - 1

    current = lines[result]
    next_line = lines[result + 1] if result + 1 < len(lines) else None
    end = next_line.timestamp if next_line else max(current.timestamp + 4.0, document.duration)
    span = max(0.001, end - current.timestamp)
    progress = min(max((effective - current.timestamp) / span, 0.0), 1.0)
    remaining = end - effective
    transition = (
        0.0
        if next_line is None
        else min(max(1.0 - remaining / max(0.05, transition_window), 0.0), 1.0)
    )

    def at(index: int) -> LyricLine | None:
        return lines[index] if 0 <= index < len(lines) else None

    karaoke_eligible = (
        next_line is not None
        and bool(current.text.strip())
        and next_line.timestamp > current.timestamp + 0.05
    )

    return LyricFrame(
        result,
        at(result - 2),
        at(result - 1),
        current,
        at(result + 1),
        at(result + 2),
        progress,
        transition,
        karaoke_eligible,
    )


def format_clock(seconds: float) -> str:
    if not math.isfinite(seconds):
        return "0:00"
    total = max(0, int(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"


def normalize_text(value: str) -> str:
    value = value.lower()
    value = re.sub(
        r"\s*[\(\[].*?(feat\.?|featuring|with|remaster(?:ed)?|live|edit|version).*?[\)\]]",
        "",
        value,
        flags=re.IGNORECASE,
    )
    value = re.sub(r"[^\w]+", " ", value, flags=re.UNICODE)
    return " ".join(value.split())


def similarity(lhs: str, rhs: str) -> float:
    left, right = normalize_text(lhs), normalize_text(rhs)
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    if left in right or right in left:
        return 0.9
    a, b = set(left.split()), set(right.split())
    return len(a & b) / len(a | b) if a | b else 0.0


def document_to_json(document: LyricsDocument) -> dict:
    return {
        "track_title": document.track_title,
        "artist_name": document.artist_name,
        "album_name": document.album_name,
        "duration": document.duration,
        "provider": document.provider,
        "provider_id": document.provider_id,
        "instrumental": document.instrumental,
        "plain_lyrics": document.plain_lyrics,
        "lines": [line.__dict__ for line in document.lines],
    }


def document_from_json(data: dict) -> LyricsDocument:
    return LyricsDocument(
        track_title=str(data.get("track_title", "")),
        artist_name=str(data.get("artist_name", "")),
        album_name=data.get("album_name"),
        duration=float(data.get("duration", 0.0)),
        provider=str(data.get("provider", "unknown")),
        provider_id=data.get("provider_id"),
        instrumental=bool(data.get("instrumental", False)),
        plain_lyrics=data.get("plain_lyrics"),
        lines=[LyricLine(**line) for line in data.get("lines", [])],
    )
