"""Sub-pixel lyric compositor used by the LyriCar Windows preview.

Tk Canvas text can only switch between integer font sizes. The previous preview
reduced CPU load by jumping in two-point increments, but a long transition made
those discrete steps visible. This module renders each lyric line once at high
resolution, builds quarter-pixel scale masks ahead of the next transition, and
composites a single transparent image for Tk. The expensive font rasterization
therefore stays out of the 60 Hz UI loop.
"""
from __future__ import annotations

from collections import OrderedDict
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
import math
import os
import threading
from typing import Iterable, Sequence

from PIL import Image, ImageDraw, ImageFont

from lyricar_core import LyricsDocument


SUPERSAMPLE = 4
MIN_FONT_PX = 9.0
MAX_SCALED_MASKS = 1600
MAX_BASE_MASKS = 96
MAX_LAYOUTS = 256


@dataclass(frozen=True)
class LineLayout:
    display_text: str
    fitted_active_size: int


@dataclass(frozen=True)
class RenderedLyrics:
    image: Image.Image
    top: int
    transition: float


class PillowLyricsRenderer:
    """Pre-rendered, sub-pixel lyric renderer.

    The cache key uses quarter-pixel font units. At a 54 px active line this
    provides roughly four times as many scale positions as integer font sizes
    and eight times as many as the old two-point Tk quantization.
    """

    def __init__(self, font_path: str | Path | None = None) -> None:
        self.font_path = str(font_path or self._resolve_font_path())
        self._lock = threading.RLock()
        self._font_cache: dict[int, ImageFont.FreeTypeFont] = {}
        self._layout_cache: OrderedDict[tuple[str, int, int], LineLayout] = OrderedDict()
        self._base_mask_cache: OrderedDict[tuple[str, int], Image.Image] = OrderedDict()
        self._scaled_mask_cache: OrderedDict[tuple[str, int, int], Image.Image] = OrderedDict()
        self._shifted_mask_cache: OrderedDict[tuple[str, int, int, int], Image.Image] = OrderedDict()
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="LyriCarGlyphs")
        self._prewarm_future: Future[None] | None = None
        self._prewarm_key: tuple[object, ...] | None = None
        self._generation = 0
        self._closed = False

    @staticmethod
    def _resolve_font_path() -> Path:
        candidates: list[Path] = []
        windows_root = Path(os.environ.get("WINDIR", r"C:\Windows"))
        candidates.extend(
            [
                windows_root / "Fonts" / "seguisb.ttf",  # Segoe UI Semibold
                windows_root / "Fonts" / "segoeuib.ttf",  # Segoe UI Bold
                windows_root / "Fonts" / "segoeui.ttf",
                Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
                Path("/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"),
                Path("/Library/Fonts/Arial Bold.ttf"),
                Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
            ]
        )
        for candidate in candidates:
            if candidate.is_file():
                return candidate
        raise RuntimeError(
            "Nessun carattere compatibile trovato. Su Windows è richiesto Segoe UI."
        )

    @staticmethod
    def smoothstep(value: float) -> float:
        value = min(max(float(value), 0.0), 1.0)
        return value * value * (3.0 - 2.0 * value)

    @classmethod
    def transition_curve(cls, value: float) -> float:
        """Ease without the long stationary endpoints of pure smoothstep."""

        value = min(max(float(value), 0.0), 1.0)
        return 0.20 * value + 0.80 * cls.smoothstep(value)

    @staticmethod
    def interpolate(value: float, points: Sequence[tuple[float, float]]) -> float:
        if value <= points[0][0]:
            return points[0][1]
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            if value <= x1:
                fraction = (value - x0) / max(0.0001, x1 - x0)
                return y0 + (y1 - y0) * fraction
        return points[-1][1]

    @staticmethod
    def quarter_units(font_size: float) -> int:
        """Convert a display-pixel font size to quarter-pixel units."""

        return max(int(MIN_FONT_PX * SUPERSAMPLE), int(round(float(font_size) * SUPERSAMPLE)))

    def _font(self, pixel_size: int) -> ImageFont.FreeTypeFont:
        pixel_size = max(1, int(pixel_size))
        with self._lock:
            cached = self._font_cache.get(pixel_size)
            if cached is None:
                cached = ImageFont.truetype(self.font_path, pixel_size)
                self._font_cache[pixel_size] = cached
            return cached

    @staticmethod
    def _touch_lru(cache: OrderedDict, key: object, value: object, limit: int) -> None:
        cache[key] = value
        cache.move_to_end(key)
        while len(cache) > limit:
            cache.popitem(last=False)

    def _measure(self, text: str, size: int) -> tuple[float, float]:
        font = self._font(size)
        draw = ImageDraw.Draw(Image.new("L", (1, 1), 0))
        bbox = draw.multiline_textbbox(
            (0, 0),
            text,
            font=font,
            spacing=max(2, int(round(size * 0.14))),
            align="center",
        )
        return float(bbox[2] - bbox[0]), float(bbox[3] - bbox[1])

    def layout_line(self, text: str, active_size: int, target_width: float) -> LineLayout:
        source = (text or "…").strip() or "…"
        width_key = max(1, int(round(float(target_width) / 4.0) * 4))
        key = (source, max(1, int(active_size)), width_key)
        with self._lock:
            cached = self._layout_cache.get(key)
            if cached is not None:
                self._layout_cache.move_to_end(key)
                return cached

        display = source
        width, _ = self._measure(display, active_size)
        words = source.split()
        if width > width_key and len(words) > 1:
            best: tuple[float, str, float] | None = None
            for split in range(1, len(words)):
                first = " ".join(words[:split])
                second = " ".join(words[split:])
                first_width, _ = self._measure(first, active_size)
                second_width, _ = self._measure(second, active_size)
                widest = max(first_width, second_width)
                balance = abs(first_width - second_width)
                # Fitting is dominant; balanced rows break near-equal ties.
                score = widest * 1000.0 + balance
                if best is None or score < best[0]:
                    best = (score, first + "\n" + second, widest)
            if best is not None:
                display = best[1]
                width = best[2]

        fitted = max(1, int(active_size))
        if width > width_key:
            low, high = int(MIN_FONT_PX), fitted
            while low <= high:
                middle = (low + high) // 2
                measured = max(self._measure(part, middle)[0] for part in display.split("\n"))
                if measured <= width_key:
                    low = middle + 1
                else:
                    high = middle - 1
            fitted = max(int(MIN_FONT_PX), high)

        result = LineLayout(display_text=display, fitted_active_size=fitted)
        with self._lock:
            self._touch_lru(self._layout_cache, key, result, MAX_LAYOUTS)
        return result

    def _base_mask(self, layout: LineLayout) -> Image.Image:
        key = (layout.display_text, layout.fitted_active_size)
        with self._lock:
            cached = self._base_mask_cache.get(key)
            if cached is not None:
                self._base_mask_cache.move_to_end(key)
                return cached

        font_size = layout.fitted_active_size * SUPERSAMPLE
        font = self._font(font_size)
        spacing = max(4, int(round(font_size * 0.14)))
        probe = ImageDraw.Draw(Image.new("L", (1, 1), 0))
        bbox = probe.multiline_textbbox(
            (0, 0),
            layout.display_text,
            font=font,
            spacing=spacing,
            align="center",
            anchor="ma",
        )
        padding = 4 * SUPERSAMPLE
        width = max(1, int(math.ceil(bbox[2] - bbox[0])) + padding * 2)
        height = max(1, int(math.ceil(bbox[3] - bbox[1])) + padding * 2)
        mask = Image.new("L", (width, height), 0)
        draw = ImageDraw.Draw(mask)
        draw.multiline_text(
            (width / 2.0, padding - bbox[1]),
            layout.display_text,
            font=font,
            fill=255,
            spacing=spacing,
            align="center",
            anchor="ma",
        )

        with self._lock:
            existing = self._base_mask_cache.get(key)
            if existing is not None:
                self._base_mask_cache.move_to_end(key)
                return existing
            self._touch_lru(self._base_mask_cache, key, mask, MAX_BASE_MASKS)
        return mask

    def _scaled_mask(self, layout: LineLayout, scale_units: int) -> Image.Image:
        scale_units = max(int(MIN_FONT_PX * SUPERSAMPLE), int(scale_units))
        key = (layout.display_text, layout.fitted_active_size, scale_units)
        with self._lock:
            cached = self._scaled_mask_cache.get(key)
            if cached is not None:
                self._scaled_mask_cache.move_to_end(key)
                return cached

        base = self._base_mask(layout)
        active_units = max(1, layout.fitted_active_size * SUPERSAMPLE)
        ratio = scale_units / active_units
        # Resize directly from the 4x source into the display-sized mask. The
        # former two-stage resize preserved the same geometry but cost roughly
        # five times more CPU, allowing the preheater to compete with Tk.
        output_width = max(1, int(round(base.width * ratio / SUPERSAMPLE)))
        output_height = max(1, int(round(base.height * ratio / SUPERSAMPLE)))
        mask = base.resize(
            (output_width, output_height),
            Image.Resampling.BILINEAR,
        )

        with self._lock:
            existing = self._scaled_mask_cache.get(key)
            if existing is not None:
                self._scaled_mask_cache.move_to_end(key)
                return existing
            self._touch_lru(self._scaled_mask_cache, key, mask, MAX_SCALED_MASKS)
        return mask

    def _shifted_mask(
        self,
        layout: LineLayout,
        scale_units: int,
        vertical_phase: int,
    ) -> Image.Image:
        """Return one of four cached vertical sub-pixel phases."""

        vertical_phase = int(vertical_phase) % SUPERSAMPLE
        if vertical_phase == 0:
            return self._scaled_mask(layout, scale_units)
        key = (
            layout.display_text,
            layout.fitted_active_size,
            int(scale_units),
            vertical_phase,
        )
        with self._lock:
            cached = self._shifted_mask_cache.get(key)
            if cached is not None:
                self._shifted_mask_cache.move_to_end(key)
                return cached

        source = self._scaled_mask(layout, scale_units)
        # One extra row prevents clipping while bilinear interpolation moves the
        # antialiased glyph by 0.25/0.50/0.75 pixel.
        shifted = source.transform(
            (source.width, source.height + 1),
            Image.Transform.AFFINE,
            (1.0, 0.0, 0.0, 0.0, 1.0, -vertical_phase / SUPERSAMPLE),
            resample=Image.Resampling.BILINEAR,
            fillcolor=0,
        )
        with self._lock:
            self._touch_lru(
                self._shifted_mask_cache,
                key,
                shifted,
                MAX_SCALED_MASKS,
            )
        return shifted

    @staticmethod
    def _visible_indices(document: LyricsDocument, current_index: int) -> range:
        return range(
            max(0, current_index - 2),
            min(len(document.lines), current_index + 4),
        )

    @staticmethod
    def _style_points(portrait: bool, fade_strength: float):
        offset_points = (
            ((0, 0.0), (1, 0.17), (2, 0.30), (3, 0.395), (4, 0.47))
            if portrait
            else ((0, 0.0), (1, 0.16), (2, 0.27), (3, 0.355), (4, 0.42))
        )
        size_points = ((0, 1.0), (1, 0.64), (2, 0.43), (3, 0.29), (4, 0.20))
        brightness_points = (
            (0, 248),
            (1, max(78, 170 / fade_strength)),
            (2, max(32, 80 / fade_strength)),
            (3, max(15, 35 / fade_strength)),
            (4, 8),
        )
        return offset_points, size_points, brightness_points

    def prepare_transition(
        self,
        document: LyricsDocument,
        current_index: int,
        *,
        width: int,
        height: int,
        active_size: int,
        portrait: bool,
        asynchronous: bool = True,
    ) -> None:
        """Prebuild all quarter-pixel masks needed by the next line change."""

        target_width = width * (0.86 if portrait else 0.88)
        _, size_points, _ = self._style_points(portrait, 1.0)
        work: list[tuple[LineLayout, int, int]] = []
        for index in self._visible_indices(document, current_index):
            layout = self.layout_line(document.lines[index].text, active_size, target_width)
            start_relative = index - current_index
            end_relative = start_relative - 1.0
            start_factor = self.interpolate(abs(start_relative), size_points)
            end_factor = self.interpolate(abs(end_relative), size_points)
            start_units = self.quarter_units(layout.fitted_active_size * start_factor)
            end_units = self.quarter_units(layout.fitted_active_size * end_factor)
            work.append((layout, min(start_units, end_units), max(start_units, end_units)))

        key: tuple[object, ...] = (
            id(document),
            current_index,
            width,
            height,
            active_size,
            portrait,
            tuple((item[0].display_text, item[0].fitted_active_size, item[1], item[2]) for item in work),
        )
        with self._lock:
            if self._closed or key == self._prewarm_key:
                return
            self._prewarm_key = key
            self._generation += 1
            generation = self._generation

        def worker() -> None:
            for layout, minimum, maximum in work:
                for units in range(minimum, maximum + 1):
                    with self._lock:
                        if self._closed or generation != self._generation:
                            return
                    self._scaled_mask(layout, units)

        if asynchronous:
            self._prewarm_future = self._executor.submit(worker)
        else:
            worker()

    def render(
        self,
        document: LyricsDocument,
        current_index: int,
        transition_progress: float,
        *,
        line_progress: float = 0.0,
        karaoke_eligible: bool = False,
        width: int,
        height: int,
        active_size: int,
        fade_strength: float,
        portrait: bool,
    ) -> RenderedLyrics:
        transition = self.transition_curve(transition_progress)
        self.prepare_transition(
            document,
            current_index,
            width=width,
            height=height,
            active_size=active_size,
            portrait=portrait,
            asynchronous=True,
        )

        top = max(0, int(math.floor(height * 0.075)))
        bottom = min(height, int(math.ceil(height * 0.775)))
        panel = Image.new("RGB", (width, max(1, bottom - top)), (8, 9, 12))
        center_y = height * 0.425
        target_width = width * (0.86 if portrait else 0.88)
        offset_points, size_points, brightness_points = self._style_points(
            portrait,
            max(0.05, fade_strength),
        )

        for index in self._visible_indices(document, current_index):
            relative = index - current_index - transition
            if not -2.65 <= relative <= 2.65:
                continue
            distance = abs(relative)
            direction = -1 if relative < 0 else 1
            y_center = center_y + direction * height * self.interpolate(distance, offset_points)
            size_factor = self.interpolate(distance, size_points)
            brightness = self.interpolate(distance, brightness_points)
            gray = max(5, min(255, int(round(brightness))))

            layout = self.layout_line(document.lines[index].text, active_size, target_width)
            scale_units = self.quarter_units(layout.fitted_active_size * size_factor)
            top_float = y_center - top
            mask = self._scaled_mask(layout, scale_units)
            x = int(round(width / 2.0 - mask.width / 2.0))
            y = int(round(top_float - mask.height / 2.0))
            panel.paste(
                (gray, gray, min(255, gray + 4)),
                (x, y),
                mask,
            )

            # The current line can receive a karaoke highlight only when a
            # real following timestamp exists. Without that timing data the
            # renderer remains byte-for-byte equivalent to the approved view.
            if index == current_index and karaoke_eligible and document.lines[index].text.strip():
                progress = min(max(float(line_progress), 0.0), 1.0)
                characters = max(1, len(document.lines[index].text))
                exact = progress * characters
                completed = min(characters, int(math.floor(exact)))
                partial = exact - completed
                visual_progress = min(1.0, (completed + partial) / characters)
                lit_width = int(round(mask.width * visual_progress))
                if lit_width > 0:
                    lit_mask = mask.crop((0, 0, lit_width, mask.height))
                    panel.paste(
                        (255, 255, 255),
                        (x, y),
                        lit_mask,
                    )

        return RenderedLyrics(image=panel, top=top, transition=transition)

    def cache_stats(self) -> dict[str, int]:
        with self._lock:
            return {
                "fonts": len(self._font_cache),
                "layouts": len(self._layout_cache),
                "base_masks": len(self._base_mask_cache),
                "scaled_masks": len(self._scaled_mask_cache),
                "shifted_masks": len(self._shifted_mask_cache),
            }

    def clear(self) -> None:
        with self._lock:
            self._generation += 1
            self._prewarm_key = None
            self._layout_cache.clear()
            self._base_mask_cache.clear()
            self._scaled_mask_cache.clear()
            self._shifted_mask_cache.clear()

    def close(self) -> None:
        with self._lock:
            if self._closed:
                return
            self._closed = True
            self._generation += 1
        self._executor.shutdown(wait=False, cancel_futures=True)
