"""Windows local Now Playing adapter for LyriCar.

This adapter reads and controls the active Spotify media session through
Windows.Media.Control (GSMTC), the same system surface used by media overlays
and desktop tools such as Toastify. It does not require a Spotify Client ID.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import sys
import threading
from typing import Any

from lyricar_core import PlaybackState, Track


class WindowsMediaError(RuntimeError):
    """Base error raised by the local Windows media adapter."""


class WindowsMediaDependencyError(WindowsMediaError):
    """Raised when the optional PyWinRT projection is not installed."""


class WindowsMediaClient:
    """Synchronous facade over the asynchronous Windows GSMTC API.

    WinRT calls live on one dedicated asyncio loop to avoid repeatedly creating
    event loops and media-session managers while the preview polls playback.
    """

    def __init__(self) -> None:
        if sys.platform != "win32":
            raise WindowsMediaError("La modalità Spotify locale è disponibile soltanto su Windows")

        try:
            import winrt.windows.media.control as media_control  # type: ignore[import-not-found]
        except ImportError as exc:
            raise WindowsMediaDependencyError(
                "Manca il componente Windows Media Control. Avvia run_spotify_locale.bat: "
                "verrà installato automaticamente una sola volta."
            ) from exc

        self._media = media_control
        self._loop = asyncio.new_event_loop()
        self._ready = threading.Event()
        self._thread = threading.Thread(
            target=self._run_loop,
            name="LyriCar-WindowsMedia",
            daemon=True,
        )
        self._manager: Any | None = None
        self._closed = False
        self._thread.start()
        if not self._ready.wait(5.0):
            raise WindowsMediaError("Impossibile inizializzare il controllo multimediale di Windows")

    def _run_loop(self) -> None:
        asyncio.set_event_loop(self._loop)
        self._ready.set()
        self._loop.run_forever()
        pending = asyncio.all_tasks(self._loop)
        for task in pending:
            task.cancel()
        if pending:
            self._loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
        self._loop.close()

    def _run(self, coroutine, timeout: float = 12.0):
        if self._closed:
            raise WindowsMediaError("Il controllo multimediale di Windows è stato chiuso")
        future = asyncio.run_coroutine_threadsafe(coroutine, self._loop)
        try:
            return future.result(timeout=timeout)
        except TimeoutError as exc:
            future.cancel()
            raise WindowsMediaError("Windows non ha risposto alla richiesta multimediale") from exc
        except WindowsMediaError:
            raise
        except Exception as exc:
            raise WindowsMediaError(f"Controllo multimediale Windows: {exc}") from exc

    async def _ensure_manager(self):
        if self._manager is None:
            manager_type = self._media.GlobalSystemMediaTransportControlsSessionManager
            self._manager = await manager_type.request_async()
        return self._manager

    async def _select_session(self):
        manager = await self._ensure_manager()
        try:
            sessions = list(manager.get_sessions())
        except Exception:
            sessions = []

        # Prefer the real Spotify session even when another player briefly gains focus.
        for session in sessions:
            source = str(getattr(session, "source_app_user_model_id", "") or "").lower()
            if "spotify" in source:
                return session

        current = manager.get_current_session()
        if current is not None:
            return current
        return sessions[0] if sessions else None

    @staticmethod
    def _timespan_seconds(value: Any) -> float:
        if value is None:
            return 0.0
        total_seconds = getattr(value, "total_seconds", None)
        if callable(total_seconds):
            try:
                return float(total_seconds())
            except Exception:
                pass
        duration = getattr(value, "duration", None)
        if duration is not None:
            try:
                return float(duration) / 10_000_000.0
            except (TypeError, ValueError):
                pass
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return 0.0
        # Raw WinRT TimeSpan values are expressed in 100-nanosecond ticks.
        return numeric / 10_000_000.0 if abs(numeric) > 100_000 else numeric

    @staticmethod
    def _timeline_sample_age(value: Any, now_utc: datetime | None = None) -> float:
        """Return how old a GSMTC timeline sample is, in seconds.

        Recent PyWinRT releases project ``Windows.Foundation.DateTime`` as a
        Python ``datetime``.  The fallback also supports the raw WinRT
        ``universal_time`` representation used by older projections.
        """
        if value is None:
            return 0.0
        now_utc = now_utc or datetime.now(timezone.utc)
        sample_time: datetime | None = None

        if isinstance(value, datetime):
            sample_time = value
        else:
            universal_time = getattr(value, "universal_time", None)
            if universal_time is not None:
                try:
                    # 100-nanosecond ticks since 1601-01-01 UTC.
                    unix_seconds = float(universal_time) / 10_000_000.0 - 11_644_473_600.0
                    sample_time = datetime.fromtimestamp(unix_seconds, timezone.utc)
                except (OverflowError, OSError, TypeError, ValueError):
                    sample_time = None

        if sample_time is None:
            return 0.0
        if sample_time.tzinfo is None:
            sample_time = sample_time.replace(tzinfo=timezone.utc)
        else:
            sample_time = sample_time.astimezone(timezone.utc)
        age = (now_utc - sample_time).total_seconds()
        if not (0.0 <= age <= 10.0):
            return 0.0
        return age

    def current_playback(self) -> PlaybackState | None:
        return self._run(self._current_playback_async())

    async def _current_playback_async(self) -> PlaybackState | None:
        session = await self._select_session()
        if session is None:
            return None

        properties = await session.try_get_media_properties_async()
        if properties is None:
            return None

        title = str(getattr(properties, "title", "") or "").strip()
        artist = str(getattr(properties, "artist", "") or "").strip()
        album = str(getattr(properties, "album_title", "") or "").strip() or None
        if not title:
            return None

        timeline = session.get_timeline_properties()
        start = self._timespan_seconds(getattr(timeline, "start_time", None))
        end = self._timespan_seconds(getattr(timeline, "end_time", None))
        position_raw = self._timespan_seconds(getattr(timeline, "position", None))
        duration = max(0.0, end - start)
        playback_info = session.get_playback_info()
        status = getattr(playback_info, "playback_status", None)
        playing_status = getattr(
            self._media.GlobalSystemMediaTransportControlsSessionPlaybackStatus,
            "PLAYING",
            None,
        )
        is_playing = status == playing_status or str(status).lower().endswith("playing")

        position = max(0.0, position_raw - start)
        if is_playing:
            position += self._timeline_sample_age(
                getattr(timeline, "last_updated_time", None)
            )
        if duration <= 0.0:
            duration = max(end, position + 1.0)
        position = min(position, duration)

        source = str(getattr(session, "source_app_user_model_id", "") or "spotify")

        track = Track(
            title=title,
            artists=[artist] if artist else ["Spotify"],
            album=album,
            duration=duration,
            track_id=f"windows:{source}:{title}:{artist}:{round(duration)}",
        )
        return PlaybackState(track=track, position=position, is_playing=is_playing)

    def play(self) -> None:
        self._run(self._control_async("try_play_async", "Play"))

    def pause(self) -> None:
        self._run(self._control_async("try_pause_async", "Pausa"))

    def next(self) -> None:
        self._run(self._control_async("try_skip_next_async", "Brano successivo"))

    def previous(self) -> None:
        self._run(self._control_async("try_skip_previous_async", "Brano precedente"))

    async def _control_async(self, method_name: str, label: str) -> None:
        session = await self._select_session()
        if session is None:
            raise WindowsMediaError("Apri Spotify e avvia prima un brano")
        method = getattr(session, method_name, None)
        if method is None:
            raise WindowsMediaError(f"Il player attivo non supporta il comando {label}")
        accepted = await method()
        if accepted is False:
            raise WindowsMediaError(f"Spotify non ha accettato il comando {label}")

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self._loop.is_running():
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread.is_alive():
            self._thread.join(timeout=1.5)
