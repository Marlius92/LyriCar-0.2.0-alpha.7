import asyncio
from datetime import datetime, timedelta, timezone
import sys
import types
import unittest
from unittest.mock import patch

from windows_media_client import WindowsMediaClient


class _TimeSpan:
    def __init__(self, seconds: float):
        self.duration = int(seconds * 10_000_000)


class _Properties:
    title = "Test Song"
    artist = "Test Artist"
    album_title = "Test Album"


class _Timeline:
    start_time = _TimeSpan(0)
    position = _TimeSpan(42.5)
    end_time = _TimeSpan(180)


class _PlaybackInfo:
    playback_status = "playing"


class _Session:
    source_app_user_model_id = "SpotifyAB.SpotifyMusic_test!Spotify"

    async def try_get_media_properties_async(self):
        return _Properties()

    def get_timeline_properties(self):
        return _Timeline()

    def get_playback_info(self):
        return _PlaybackInfo()

    async def try_play_async(self):
        return True

    async def try_pause_async(self):
        return True

    async def try_skip_next_async(self):
        return True

    async def try_skip_previous_async(self):
        return True


class _Manager:
    def __init__(self):
        self.session = _Session()

    def get_sessions(self):
        return [self.session]

    def get_current_session(self):
        return self.session


class _ManagerType:
    @staticmethod
    async def request_async():
        await asyncio.sleep(0)
        return _Manager()


class _Status:
    PLAYING = "playing"


def _install_fake_winrt():
    winrt = types.ModuleType("winrt")
    windows = types.ModuleType("winrt.windows")
    media = types.ModuleType("winrt.windows.media")
    control = types.ModuleType("winrt.windows.media.control")
    control.GlobalSystemMediaTransportControlsSessionManager = _ManagerType
    control.GlobalSystemMediaTransportControlsSessionPlaybackStatus = _Status
    return patch.dict(
        sys.modules,
        {
            "winrt": winrt,
            "winrt.windows": windows,
            "winrt.windows.media": media,
            "winrt.windows.media.control": control,
        },
    )


class WindowsMediaClientTests(unittest.TestCase):
    def test_timeline_sample_age_uses_last_updated_time(self):
        now = datetime(2026, 8, 23, 12, 0, 0, tzinfo=timezone.utc)
        sample = now - timedelta(milliseconds=650)
        self.assertAlmostEqual(
            WindowsMediaClient._timeline_sample_age(sample, now),
            0.65,
            places=3,
        )

    def test_implausibly_old_timeline_sample_is_ignored(self):
        now = datetime(2026, 8, 23, 12, 0, 0, tzinfo=timezone.utc)
        sample = now - timedelta(minutes=1)
        self.assertEqual(WindowsMediaClient._timeline_sample_age(sample, now), 0.0)

    def test_reads_track_timeline_and_controls(self):
        with patch.object(sys, "platform", "win32"), _install_fake_winrt():
            client = WindowsMediaClient()
            try:
                playback = client.current_playback()
                self.assertIsNotNone(playback)
                assert playback is not None
                self.assertEqual(playback.track.title, "Test Song")
                self.assertEqual(playback.track.primary_artist, "Test Artist")
                self.assertAlmostEqual(playback.position, 42.5)
                self.assertAlmostEqual(playback.track.duration, 180.0)
                self.assertTrue(playback.is_playing)
                client.pause()
                client.play()
                client.previous()
                client.next()
            finally:
                client.close()


if __name__ == "__main__":
    unittest.main()
