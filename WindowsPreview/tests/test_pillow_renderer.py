import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lyricar_core import LyricsDocument, LyricLine
from pillow_lyrics_renderer import PillowLyricsRenderer


class PillowLyricsRendererTests(unittest.TestCase):
    def setUp(self):
        self.renderer = PillowLyricsRenderer()
        self.document = LyricsDocument(
            track_title="Song",
            artist_name="Artist",
            duration=30,
            lines=[
                LyricLine(0, 0.0, "A deliberately long lyric line that needs stable wrapping"),
                LyricLine(1, 4.0, "Second line"),
                LyricLine(2, 8.0, "Third line"),
                LyricLine(3, 12.0, "Fourth line"),
            ],
        )

    def tearDown(self):
        self.renderer.close()

    def test_long_line_layout_is_stable_and_fits(self):
        layout1 = self.renderer.layout_line(self.document.lines[0].text, 48, 380)
        layout2 = self.renderer.layout_line(self.document.lines[0].text, 48, 380)
        self.assertEqual(layout1, layout2)
        self.assertIn("\n", layout1.display_text)
        self.assertLessEqual(layout1.fitted_active_size, 48)

    def test_render_returns_rgb_panel_for_fast_tk_upload(self):
        rendered = self.renderer.render(
            self.document,
            0,
            0.5,
            width=600,
            height=800,
            active_size=48,
            fade_strength=1.0,
            portrait=True,
        )
        self.assertEqual(rendered.image.mode, "RGB")
        self.assertEqual(rendered.image.width, 600)
        self.assertGreater(rendered.image.height, 400)
        self.assertGreater(rendered.image.getbbox()[2], 0)

    def test_future_karaoke_line_is_detected_only_with_following_timestamp(self):
        self.assertTrue(self.renderer._line_karaoke_eligible(self.document, 1))
        self.assertFalse(self.renderer._line_karaoke_eligible(self.document, 3))

    def test_transition_masks_can_be_prepared_before_animation(self):
        self.renderer.prepare_transition(
            self.document,
            0,
            width=600,
            height=800,
            active_size=48,
            portrait=True,
            asynchronous=False,
        )
        stats = self.renderer.cache_stats()
        self.assertGreater(stats["scaled_masks"], 80)
        self.assertGreater(stats["base_masks"], 0)


if __name__ == "__main__":
    unittest.main()
