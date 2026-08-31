import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lyricar_core import (
    LyricsDocument,
    LyricLine,
    PlaybackReconciler,
    PlaybackState,
    Track,
    build_frame,
    format_clock,
    parse_lrc,
)
from lyricar_preview import LyriCarPreview
from pillow_lyrics_renderer import PillowLyricsRenderer


class ParserTests(unittest.TestCase):
    def test_multiple_timestamps_and_offset(self):
        lines, metadata, offset = parse_lrc(
            "[ar:Artist]\n[offset:250]\n[00:01.50][00:03.00]Line\n[00:05.00]Next"
        )
        self.assertEqual(metadata["ar"], "Artist")
        self.assertAlmostEqual(offset, 0.25)
        self.assertEqual(len(lines), 3)
        self.assertAlmostEqual(lines[0].timestamp, 1.75)

    def test_hour_timestamp(self):
        lines, _, _ = parse_lrc("[01:02:03.500]Long")
        self.assertAlmostEqual(lines[0].timestamp, 3723.5)


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.document = LyricsDocument(
            track_title="Song",
            artist_name="Artist",
            duration=30,
            lines=[LyricLine(i, 2 + i * 4, str(i)) for i in range(5)],
        )

    def test_five_line_window(self):
        frame = build_frame(self.document, 10.5)
        self.assertEqual(frame.current.text, "2")
        self.assertEqual(frame.previous2.text, "0")
        self.assertEqual(frame.next2.text, "4")

    def test_positive_offset_delays(self):
        frame = build_frame(self.document, 10.5, user_offset=1.0)
        self.assertEqual(frame.current.text, "1")

    def test_format_clock(self):
        self.assertEqual(format_clock(62.9), "1:02")
        self.assertEqual(format_clock(3661), "1:01:01")

    def test_karaoke_requires_real_following_timestamp(self):
        middle = build_frame(self.document, 10.5)
        self.assertTrue(middle.karaoke_eligible)
        self.assertGreater(middle.line_progress, 0.0)

        last = build_frame(self.document, 19.0)
        self.assertFalse(last.karaoke_eligible)


class PlaybackReconcilerTests(unittest.TestCase):
    def setUp(self):
        self.track = Track(
            title="Song",
            artists=["Artist"],
            duration=300,
            track_id="track-1",
        )

    def sample(self, position: float, captured: float, playing: bool = True) -> PlaybackState:
        return PlaybackState(
            track=self.track,
            position=position,
            is_playing=playing,
            captured_monotonic=captured,
        )

    def test_quantized_playing_samples_never_pull_clock_backwards(self):
        reconciler = PlaybackReconciler()
        first = reconciler.apply(self.sample(10.0, 0.0), now=0.0)
        self.assertIsNotNone(first)
        assert first is not None
        self.assertAlmostEqual(first.estimated_position(0.8), 10.8)

        # GSMTC can return the same whole-second position on the next poll.
        second = reconciler.apply(self.sample(10.0, 0.9), now=0.9)
        self.assertIsNotNone(second)
        assert second is not None
        self.assertGreaterEqual(second.position, 10.89)
        self.assertGreaterEqual(second.estimated_position(1.2), 11.19)

        # The next coarse sample catches up without moving the renderer back.
        third = reconciler.apply(self.sample(11.0, 1.8), now=1.8)
        self.assertIsNotNone(third)
        assert third is not None
        self.assertGreaterEqual(third.position, second.estimated_position(1.8) - 0.001)

    def test_real_backward_seek_is_applied_immediately(self):
        reconciler = PlaybackReconciler()
        reconciler.apply(self.sample(50.0, 0.0), now=0.0)
        sought = reconciler.apply(self.sample(12.0, 1.0), now=1.0)
        self.assertIsNotNone(sought)
        assert sought is not None
        self.assertAlmostEqual(sought.position, 12.0)

    def test_pause_freezes_continuous_position_instead_of_stale_raw_sample(self):
        reconciler = PlaybackReconciler()
        reconciler.apply(self.sample(20.0, 0.0, True), now=0.0)
        paused = reconciler.apply(self.sample(20.0, 0.9, False), now=0.9)
        self.assertIsNotNone(paused)
        assert paused is not None
        self.assertFalse(paused.is_playing)
        self.assertGreaterEqual(paused.position, 20.89)
        self.assertAlmostEqual(paused.estimated_position(4.0), paused.position)

    def test_seek_while_paused_is_not_filtered(self):
        reconciler = PlaybackReconciler()
        reconciler.apply(self.sample(40.0, 0.0, False), now=0.0)
        sought = reconciler.apply(self.sample(25.0, 1.0, False), now=1.0)
        self.assertIsNotNone(sought)
        assert sought is not None
        self.assertAlmostEqual(sought.position, 25.0)


class RendererTransitionTests(unittest.TestCase):
    def test_smoothstep_keeps_exact_endpoints(self):
        self.assertEqual(LyriCarPreview._smoothstep(0.0), 0.0)
        self.assertEqual(LyriCarPreview._smoothstep(1.0), 1.0)
        self.assertEqual(LyriCarPreview._smoothstep(-1.0), 0.0)
        self.assertEqual(LyriCarPreview._smoothstep(2.0), 1.0)

    def test_smoothstep_is_monotonic_and_symmetric(self):
        values = [LyriCarPreview._smoothstep(step / 20) for step in range(21)]
        self.assertEqual(values, sorted(values))
        self.assertAlmostEqual(
            LyriCarPreview._smoothstep(0.25),
            1.0 - LyriCarPreview._smoothstep(0.75),
        )

    def test_soft_transition_curve_moves_at_long_transition_endpoints(self):
        values = [PillowLyricsRenderer.transition_curve(step / 100) for step in range(101)]
        self.assertEqual(values[0], 0.0)
        self.assertEqual(values[-1], 1.0)
        self.assertEqual(values, sorted(values))
        self.assertGreater(values[1], LyriCarPreview._smoothstep(0.01))
        self.assertLess(values[-2], 1.0)

    def test_subpixel_scale_has_quarter_pixel_resolution(self):
        values = [PillowLyricsRenderer.quarter_units(9 + step * 0.25) for step in range(181)]
        self.assertTrue(all(value >= 36 for value in values))
        self.assertEqual(values, sorted(values))
        # The previous two-point renderer exposed fewer than 30 sizes here.
        self.assertGreaterEqual(len(set(values)), 175)

    def test_subpixel_scale_is_monotonic(self):
        values = [PillowLyricsRenderer.quarter_units(step / 10) for step in range(90, 741)]
        self.assertEqual(values, sorted(values))


if __name__ == "__main__":
    unittest.main()
