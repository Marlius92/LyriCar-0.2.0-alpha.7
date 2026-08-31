from __future__ import annotations

import argparse
from dataclasses import asdict
from pathlib import Path
import json
import os
import queue
import sys
import threading
import time
import webbrowser
import tkinter as tk
from tkinter import filedialog, font as tkfont, messagebox, ttk

from PIL import ImageTk

from lyricar_core import (
    LyricsDocument,
    PlaybackReconciler,
    PlaybackState,
    Track,
    build_frame,
    format_clock,
    parse_lrc_file,
)
from lrclib_client import LRCLibClient, LRCLibError
from pillow_lyrics_renderer import PillowLyricsRenderer
from spotify_client import SpotifyClient, SpotifyConfiguration, SpotifyError
from windows_media_client import (
    WindowsMediaClient,
    WindowsMediaDependencyError,
    WindowsMediaError,
)

APP_NAME = "LyriCar Preview"
APP_VERSION = "0.2.2-alpha.9"
SPOTIFY_DASHBOARD_URL = "https://developer.spotify.com/dashboard"
SPOTIFY_WEB_PLAYER_URL = "https://open.spotify.com"
TARGET_FRAME_SECONDS = 1.0 / 60.0


DISPLAY_PROFILES = {
    "renault_clio_9_3": {
        "label": 'Renault Clio — Easy Link 9,3" (verticale)',
        # Logical preview size only. CarPlay will still use the real window size
        # reported by the vehicle at runtime.
        "geometry": (600, 800),
        "minsize": (420, 560),
    },
    "generic_carplay_landscape": {
        "label": "CarPlay generico — 800×480 (orizzontale)",
        "geometry": (1000, 600),
        "minsize": (640, 384),
    },
}

DEFAULT_DISPLAY_PROFILE = "renault_clio_9_3"


def resource_path(relative: str) -> Path:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / relative


def settings_path() -> Path:
    root = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".config")) / "LyriCar"
    root.mkdir(parents=True, exist_ok=True)
    return root / "preview_settings.json"


DEFAULT_SETTINGS = {
    "spotify_client_id": "",
    "spotify_redirect_uri": "http://127.0.0.1:8765/callback",
    "lyrics_offset": 0.0,
    "font_scale": 1.0,
    "fade_strength": 1.0,
    "animation_seconds": 0.55,
    "render_engine_version": 3,
    "display_profile": DEFAULT_DISPLAY_PROFILE,
}


class LyriCarPreview:
    def __init__(self, root: tk.Tk, client_id_override: str | None = None) -> None:
        self.root = root
        self.root.title(f"{APP_NAME} {APP_VERSION}")
        self.root.configure(bg="#08090c")

        self.settings = self._load_settings()
        profile_key = str(self.settings.get("display_profile", DEFAULT_DISPLAY_PROFILE))
        if profile_key not in DISPLAY_PROFILES:
            profile_key = DEFAULT_DISPLAY_PROFILE
            self.settings["display_profile"] = profile_key
        self.display_profile_var = tk.StringVar(value=profile_key)
        self._apply_profile_geometry(profile_key)
        if client_id_override:
            self.settings["spotify_client_id"] = client_id_override
        self.event_queue: queue.Queue[tuple[str, object]] = queue.Queue()
        self.stop_poll = threading.Event()
        self.poll_thread: threading.Thread | None = None
        self.mode = "demo"
        self.fullscreen = False
        self.status_message = "Preview Windows — modalità demo"
        self.status_is_error = False
        self.playback: PlaybackState | None = None
        self.playback_reconciler = PlaybackReconciler()
        self.document: LyricsDocument | None = None
        self.loading_track_key: str | None = None
        self._font_cache: dict[tuple[str, int, str], tkfont.Font] = {}
        self._item_option_cache: dict[int, dict[str, object]] = {}
        self._item_coords_cache: dict[int, tuple[float, ...]] = {}
        self.last_geometry = (0, 0)
        self._frame_interval = TARGET_FRAME_SECONDS
        self._next_frame_deadline = time.perf_counter()
        self._frame_after_id: str | None = None
        self._closed = False
        self.lyrics_renderer = PillowLyricsRenderer()
        self._lyrics_photo: ImageTk.PhotoImage | None = None
        self._lyrics_photo_size = (0, 0)
        self._lyrics_render_key: tuple[object, ...] | None = None
        self.lrclib = LRCLibClient()
        self.spotify: SpotifyClient | None = None
        self.windows_media: WindowsMediaClient | None = None
        self._configure_spotify_client()

        self.canvas = tk.Canvas(
            root,
            bg="#08090c",
            highlightthickness=0,
            bd=0,
            cursor="arrow",
        )
        self.canvas.pack(fill="both", expand=True)
        self._create_canvas_items()
        self._create_menu()
        self._bind_shortcuts()
        self._load_demo()
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self._schedule_next_frame(immediate=True)

    def _create_canvas_items(self) -> None:
        # One transparent image carries all lyric lines. Font rasterization and
        # fractional scaling happen in Pillow, outside Tk's integer font-size
        # model, so long transitions no longer reveal size steps.
        self.lyrics_image_item = self.canvas.create_image(
            0, 0, anchor="nw", state="hidden"
        )
        self.title_item = self.canvas.create_text(
            0, 0, text="", fill="#f4f4f6", anchor="n", font=self._font("Segoe UI", 15, "bold")
        )
        self.artist_item = self.canvas.create_text(
            0, 0, text="", fill="#90939c", anchor="n", font=self._font("Segoe UI", 10)
        )
        self.status_item = self.canvas.create_text(
            0, 0, text="", fill="#7f8490", anchor="ne", font=self._font("Segoe UI", 8)
        )
        self.empty_item = self.canvas.create_text(
            0,
            0,
            text="",
            fill="#b9bbc2",
            anchor="center",
            justify="center",
            font=self._font("Segoe UI", 22, "bold"),
        )
        self.progress_track = self.canvas.create_rectangle(0, 0, 0, 0, fill="#252831", outline="")
        self.progress_fill = self.canvas.create_rectangle(0, 0, 0, 0, fill="#f3f4f6", outline="")
        self.progress_knob = self.canvas.create_oval(0, 0, 0, 0, fill="#ffffff", outline="")
        self.elapsed_item = self.canvas.create_text(0, 0, text="0:00", fill="#b7bac2", anchor="w")
        self.remaining_item = self.canvas.create_text(0, 0, text="-0:00", fill="#b7bac2", anchor="e")
        self.previous_item = self.canvas.create_text(
            0, 0, text="⏮", fill="#e7e8ec", font=self._font("Segoe UI Symbol", 24), tags=("control", "previous")
        )
        self.play_item = self.canvas.create_text(
            0, 0, text="⏸", fill="#ffffff", font=self._font("Segoe UI Symbol", 30, "bold"), tags=("control", "play")
        )
        self.next_item = self.canvas.create_text(
            0, 0, text="⏭", fill="#e7e8ec", font=self._font("Segoe UI Symbol", 24), tags=("control", "next")
        )
        self.settings_item = self.canvas.create_text(
            0, 0, text="⚙", fill="#8c9099", font=self._font("Segoe UI Symbol", 15), tags=("control", "settings")
        )
        self.canvas.tag_bind("previous", "<Button-1>", lambda _event: self.previous())
        self.canvas.tag_bind("play", "<Button-1>", lambda _event: self.toggle_play())
        self.canvas.tag_bind("next", "<Button-1>", lambda _event: self.next())
        self.canvas.tag_bind("settings", "<Button-1>", lambda _event: self.open_settings())
        self.canvas.tag_bind("control", "<Enter>", lambda _event: self.canvas.configure(cursor="hand2"))
        self.canvas.tag_bind("control", "<Leave>", lambda _event: self.canvas.configure(cursor="arrow"))


    def _font(self, family: str, size: int, weight: str = "normal") -> tkfont.Font:
        """Return a named reusable font instead of rebuilding it per frame."""

        size = max(1, int(size))
        normalized_weight = "bold" if weight == "bold" else "normal"
        key = (family, size, normalized_weight)
        cached = self._font_cache.get(key)
        if cached is None:
            cached = tkfont.Font(
                root=self.root,
                family=family,
                size=size,
                weight=normalized_weight,
            )
            self._font_cache[key] = cached
        return cached

    def _configure_item(self, item: int, **options: object) -> None:
        """Send only changed options across the relatively costly Tcl bridge."""

        previous = self._item_option_cache.setdefault(item, {})
        changed = {key: value for key, value in options.items() if previous.get(key) != value}
        if not changed:
            return
        self.canvas.itemconfigure(item, **changed)
        previous.update(changed)

    def _set_coords(self, item: int, *coords: float) -> None:
        rounded = tuple(round(float(value), 2) for value in coords)
        if self._item_coords_cache.get(item) == rounded:
            return
        self.canvas.coords(item, *coords)
        self._item_coords_cache[item] = rounded

    def _create_menu(self) -> None:
        self.menu = tk.Menu(self.root, tearoff=False)
        file_menu = tk.Menu(self.menu, tearoff=False)
        file_menu.add_command(label="Apri file LRC…", accelerator="Ctrl+L", command=self.open_lrc)
        file_menu.add_separator()
        file_menu.add_command(label="Esci", command=self.close)
        self.menu.add_cascade(label="File", menu=file_menu)

        mode_menu = tk.Menu(self.menu, tearoff=False)
        mode_menu.add_command(label="Demo locale", command=self.use_demo)
        mode_menu.add_command(
            label="Spotify locale — senza Client ID",
            command=self.use_windows_media,
        )
        mode_menu.add_command(label="Spotify Web API — con Client ID", command=self.use_spotify)
        self.menu.add_cascade(label="Modalità", menu=mode_menu)

        spotify_menu = tk.Menu(self.menu, tearoff=False)
        spotify_menu.add_command(label="Apri Spotify", command=self.open_spotify)
        spotify_menu.add_command(
            label="Usa Spotify locale — consigliato per Windows",
            command=self.use_windows_media,
        )
        spotify_menu.add_separator()
        spotify_menu.add_command(label="Apri Dashboard sviluppatori…", command=self.open_spotify_dashboard)
        spotify_menu.add_command(label="Collega Spotify Web API…", command=self.connect_spotify)
        spotify_menu.add_command(label="Scollega Spotify Web API", command=self.disconnect_spotify)
        self.menu.add_cascade(label="Spotify", menu=spotify_menu)

        view_menu = tk.Menu(self.menu, tearoff=False)
        view_menu.add_command(label="Schermo intero", accelerator="F11", command=self.toggle_fullscreen)
        display_menu = tk.Menu(view_menu, tearoff=False)
        for key, profile in DISPLAY_PROFILES.items():
            display_menu.add_radiobutton(
                label=str(profile["label"]),
                value=key,
                variable=self.display_profile_var,
                command=lambda selected=key: self.apply_display_profile(selected),
            )
        view_menu.add_cascade(label="Profilo display", menu=display_menu)
        view_menu.add_command(label="Impostazioni…", command=self.open_settings)
        self.menu.add_cascade(label="Visualizza", menu=view_menu)
        self.root.config(menu=self.menu)

    def _apply_profile_geometry(self, profile_key: str) -> None:
        profile = DISPLAY_PROFILES.get(profile_key, DISPLAY_PROFILES[DEFAULT_DISPLAY_PROFILE])
        width, height = profile["geometry"]
        min_width, min_height = profile["minsize"]
        self.root.minsize(int(min_width), int(min_height))
        self.root.geometry(f"{int(width)}x{int(height)}")

    def apply_display_profile(self, profile_key: str) -> None:
        if profile_key not in DISPLAY_PROFILES:
            return
        self.settings["display_profile"] = profile_key
        self.display_profile_var.set(profile_key)
        self._save_settings()
        if not self.fullscreen:
            self._apply_profile_geometry(profile_key)
        self._lyrics_render_key = None
        profile_label = str(DISPLAY_PROFILES[profile_key]["label"])
        self.status_message = f"Profilo: {profile_label}"
        self.status_is_error = False

    def _profile_label(self) -> str:
        profile_key = str(self.settings.get("display_profile", DEFAULT_DISPLAY_PROFILE))
        profile = DISPLAY_PROFILES.get(profile_key, DISPLAY_PROFILES[DEFAULT_DISPLAY_PROFILE])
        return str(profile["label"])

    def _bind_shortcuts(self) -> None:
        self.root.bind("<space>", lambda _event: self.toggle_play())
        self.root.bind("<F11>", lambda _event: self.toggle_fullscreen())
        self.root.bind("<Escape>", lambda _event: self.exit_fullscreen())
        self.root.bind("<Control-l>", lambda _event: self.open_lrc())
        self.root.bind("<Left>", lambda _event: self.previous())
        self.root.bind("<Right>", lambda _event: self.next())

    def _load_settings(self) -> dict:
        path = settings_path()
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            loaded = {}
        merged = {**DEFAULT_SETTINGS, **loaded}
        try:
            engine_version = int(loaded.get("render_engine_version", 1))
        except (TypeError, ValueError):
            engine_version = 1
        if engine_version < 3:
            # Preserve custom timing, but migrate every previous installation to
            # the sub-pixel Pillow compositor introduced in 0.1.5-alpha.6.
            try:
                old_duration = float(merged.get("animation_seconds", 0.45))
            except (TypeError, ValueError):
                old_duration = 0.45
            if engine_version < 2 and abs(old_duration - 0.45) < 0.001:
                merged["animation_seconds"] = 0.55
            merged["render_engine_version"] = 3
            try:
                path.write_text(json.dumps(merged, indent=2), encoding="utf-8")
            except OSError:
                pass
        return merged

    def _save_settings(self) -> None:
        settings_path().write_text(json.dumps(self.settings, indent=2), encoding="utf-8")

    def _configure_spotify_client(self) -> None:
        client_id = str(self.settings.get("spotify_client_id", "")).strip()
        self.spotify = SpotifyClient(
            SpotifyConfiguration(
                client_id=client_id,
                redirect_uri=str(self.settings.get("spotify_redirect_uri", DEFAULT_SETTINGS["spotify_redirect_uri"])),
            )
        )

    def _load_demo(self) -> None:
        self.playback_reconciler.reset()
        document = parse_lrc_file(resource_path("assets/sample.lrc"))
        track_data = json.loads(resource_path("assets/sample_track.json").read_text(encoding="utf-8"))
        track = Track(
            title=track_data["title"],
            artists=list(track_data["artists"]),
            album=track_data.get("album"),
            duration=float(track_data["duration"]),
            track_id="demo",
        )
        document.duration = track.duration
        self.document = document
        self.playback = PlaybackState(track=track, position=0.0, is_playing=True)
        self.status_message = f"{self._profile_label()} — modalità demo"
        self.status_is_error = False

    def use_demo(self) -> None:
        self._stop_spotify_poll()
        self.loading_track_key = None
        self.mode = "demo"
        self._load_demo()

    @staticmethod
    def _open_external_url(url: str) -> bool:
        opened = False
        if os.name == "nt":
            try:
                os.startfile(url)  # type: ignore[attr-defined]
                opened = True
            except (AttributeError, OSError):
                opened = False
        if not opened:
            try:
                opened = bool(webbrowser.open_new_tab(url))
            except webbrowser.Error:
                opened = False
        return opened

    def open_spotify_dashboard(self) -> None:
        if self._open_external_url(SPOTIFY_DASHBOARD_URL):
            self.status_message = "Dashboard Spotify aperta nel browser"
            self.status_is_error = False
        else:
            messagebox.showerror(
                APP_NAME,
                "Windows non riesce ad aprire il browser predefinito.",
                parent=self.root,
            )

    def open_spotify(self, silent: bool = False) -> None:
        opened = False
        if os.name == "nt":
            try:
                os.startfile("spotify:")  # type: ignore[attr-defined]
                opened = True
            except (AttributeError, OSError):
                opened = False
        if not opened:
            opened = self._open_external_url(SPOTIFY_WEB_PLAYER_URL)
        if opened:
            if not silent:
                self.status_message = "Spotify aperta — avvia un brano e torna a LyriCar"
                self.status_is_error = False
        elif not silent:
            messagebox.showerror(
                APP_NAME,
                "Non riesco ad aprire Spotify né il Web Player.",
                parent=self.root,
            )

    def use_windows_media(self) -> None:
        self._stop_spotify_poll()
        self.playback_reconciler.reset()
        if self.windows_media is None:
            try:
                self.windows_media = WindowsMediaClient()
            except WindowsMediaDependencyError as exc:
                self.status_message = str(exc)
                self.status_is_error = True
                messagebox.showerror(
                    APP_NAME,
                    f"{exc}\n\nChiudi LyriCar e avvia run_spotify_locale.bat.",
                    parent=self.root,
                )
                return
            except WindowsMediaError as exc:
                self.status_message = str(exc)
                self.status_is_error = True
                messagebox.showerror(APP_NAME, str(exc), parent=self.root)
                return
        self.mode = "windows_media"
        self.document = None
        self.playback = None
        self.loading_track_key = None
        self.status_message = "Spotify locale — avvia un brano nell'app Spotify per Windows"
        self.status_is_error = False
        self.open_spotify(silent=True)
        self._start_windows_media_poll()

    def use_spotify(self) -> None:
        if not self.spotify or not self.spotify.is_authenticated:
            self.connect_spotify(start_live_after=True)
            return
        self.mode = "spotify"
        self.playback_reconciler.reset()
        self.document = None
        self.loading_track_key = None
        self.playback = None
        self.status_message = "Spotify collegata — attendo il brano corrente"
        self.status_is_error = False
        self._start_spotify_poll()

    def connect_spotify(self, start_live_after: bool = False) -> None:
        if not self.settings.get("spotify_client_id"):
            self.open_settings(connect_after_save=True)
            return
        self.status_message = "Apro il browser per collegare Spotify…"
        self.status_is_error = False

        def worker() -> None:
            try:
                assert self.spotify is not None
                self.spotify.authenticate()
                self.event_queue.put(("authenticated", start_live_after))
            except Exception as exc:  # UI boundary
                self.event_queue.put(("error", str(exc)))

        threading.Thread(target=worker, name="SpotifyOAuth", daemon=True).start()

    def disconnect_spotify(self) -> None:
        self._stop_spotify_poll()
        if self.spotify:
            self.spotify.disconnect()
        self.use_demo()
        self.status_message = "Spotify scollegata — modalità demo"

    def _start_spotify_poll(self) -> None:
        if self.poll_thread and self.poll_thread.is_alive():
            return
        stop_event = threading.Event()
        self.stop_poll = stop_event
        self.poll_thread = threading.Thread(
            target=self._spotify_poll_loop,
            args=(stop_event,),
            name="SpotifyPoll",
            daemon=True,
        )
        self.poll_thread.start()

    def _stop_spotify_poll(self) -> None:
        self.stop_poll.set()
        self.poll_thread = None

    def _start_windows_media_poll(self) -> None:
        if self.poll_thread and self.poll_thread.is_alive():
            return
        stop_event = threading.Event()
        self.stop_poll = stop_event
        self.poll_thread = threading.Thread(
            target=self._windows_media_poll_loop,
            args=(stop_event,),
            name="WindowsMediaPoll",
            daemon=True,
        )
        self.poll_thread.start()

    def _windows_media_poll_loop(self, stop_event: threading.Event) -> None:
        while not stop_event.is_set():
            try:
                if self.windows_media is None:
                    raise WindowsMediaError("Controllo multimediale Windows non inizializzato")
                playback = self.windows_media.current_playback()
                self.event_queue.put(("playback", playback))
                if playback:
                    key = playback.track.cache_key
                    if key != self.loading_track_key:
                        self.loading_track_key = key
                        self.event_queue.put(("status", "Cerco il testo sincronizzato…"))
                        try:
                            document = self.lrclib.get_lyrics(playback.track)
                            self.event_queue.put(("lyrics", (key, document)))
                        except LRCLibError as exc:
                            self.event_queue.put(("error_nonfatal", str(exc)))
                delay = 0.9 if playback and playback.is_playing else 1.5
            except Exception as exc:
                self.event_queue.put(("error_nonfatal", str(exc)))
                delay = 2.5
            stop_event.wait(delay)

    def _spotify_poll_loop(self, stop_event: threading.Event) -> None:
        while not stop_event.is_set():
            try:
                assert self.spotify is not None
                playback = self.spotify.current_playback()
                self.event_queue.put(("playback", playback))
                if playback:
                    key = playback.track.cache_key
                    if key != self.loading_track_key:
                        self.loading_track_key = key
                        self.event_queue.put(("status", "Cerco il testo sincronizzato…"))
                        try:
                            document = self.lrclib.get_lyrics(playback.track)
                            self.event_queue.put(("lyrics", (key, document)))
                        except LRCLibError as exc:
                            self.event_queue.put(("error_nonfatal", str(exc)))
                delay = 2.25 if playback and playback.is_playing else 3.5
            except Exception as exc:
                self.event_queue.put(("error_nonfatal", str(exc)))
                delay = 4.0
            stop_event.wait(delay)

    def _drain_events(self) -> None:
        while True:
            try:
                kind, payload = self.event_queue.get_nowait()
            except queue.Empty:
                break
            if kind == "authenticated":
                self.status_message = "Spotify Web API collegata — avvia un brano"
                self.status_is_error = False
                self.open_spotify(silent=True)
                if bool(payload):
                    self.use_spotify()
            elif kind == "playback":
                raw_playback = payload
                if raw_playback is None:
                    self.playback_reconciler.apply(None)
                    self.playback = None
                    self.document = None
                    self.status_message = (
                        "Spotify locale attivo — apri Spotify e avvia un brano"
                        if self.mode == "windows_media"
                        else "Spotify Web API collegata — avvia un brano"
                    )
                else:
                    incoming: PlaybackState = raw_playback  # type: ignore[assignment]
                    old_key = self.playback.track.cache_key if self.playback else None
                    self.playback = self.playback_reconciler.apply(incoming)
                    if old_key != incoming.track.cache_key:
                        self.document = None
                self.status_is_error = False
            elif kind == "lyrics":
                key, document = payload  # type: ignore[misc]
                if self.playback and self.playback.track.cache_key == key:
                    self.document = document
                    self.status_message = (
                        "Testo sincronizzato LRCLIB"
                        if document and document.lines
                        else "Testo sincronizzato non disponibile"
                    )
                    self.status_is_error = False
            elif kind == "status":
                self.status_message = str(payload)
                self.status_is_error = False
            elif kind == "error_nonfatal":
                self.status_message = str(payload)
                self.status_is_error = True
            elif kind == "error":
                self.status_message = str(payload)
                self.status_is_error = True
                messagebox.showerror(APP_NAME, str(payload), parent=self.root)
            elif kind == "control_done":
                self.status_message = str(payload)
                self.status_is_error = False

    def _tick(self) -> None:
        """Draw against an absolute 60 Hz deadline.

        ``after(16)`` waits after drawing has completed. During a lyric change,
        text rasterization therefore used to lengthen the frame interval itself.
        This scheduler subtracts render cost from the next wait and skips stale
        frames after an occasional operating-system pause.
        """

        if self._closed:
            return
        self._drain_events()
        if self.mode == "demo" and self.playback and self.playback.is_playing:
            position = self.playback.estimated_position()
            if position >= self.playback.track.duration:
                self.playback = PlaybackState(self.playback.track, 0.0, True)
        self._draw()
        self._schedule_next_frame()

    def _schedule_next_frame(self, *, immediate: bool = False) -> None:
        if self._closed:
            return
        now = time.perf_counter()
        if immediate:
            self._next_frame_deadline = now
            delay_ms = 0
        else:
            self._next_frame_deadline += self._frame_interval
            if self._next_frame_deadline < now - self._frame_interval:
                self._next_frame_deadline = now + self._frame_interval
            delay_ms = max(
                1,
                int(round((self._next_frame_deadline - now) * 1000.0)),
            )
        self._frame_after_id = self.root.after(delay_ms, self._tick)

    def _draw(self) -> None:
        width = max(1, self.canvas.winfo_width())
        height = max(1, self.canvas.winfo_height())
        portrait = height > width * 1.12
        self.last_geometry = (width, height)
        playback = self.playback
        position = playback.estimated_position() if playback else 0.0
        duration = playback.track.duration if playback else 0.0
        frame = build_frame(
            self.document,
            position,
            user_offset=float(self.settings.get("lyrics_offset", 0.0)),
            transition_window=float(self.settings.get("animation_seconds", 0.55)),
        )

        title = playback.track.title if playback else "LyriCar"
        artist = playback.track.display_artist if playback else "In attesa di Spotify"
        title_width = int(width * (0.84 if portrait else 0.74))
        self._set_coords(self.title_item, width / 2, height * (0.034 if portrait else 0.045))
        self._set_coords(self.artist_item, width / 2, height * (0.072 if portrait else 0.092))
        self._configure_item(self.title_item, text=title, width=title_width)
        self._configure_item(self.artist_item, text=artist, width=title_width)
        if portrait:
            self._set_coords(self.status_item, width / 2, height * 0.108)
        else:
            self._set_coords(self.status_item, width - 18, 16)
        self._configure_item(
            self.status_item,
            text=self.status_message,
            fill="#d77474" if self.status_is_error else "#747985",
            width=int(width * (0.82 if portrait else 0.30)),
            anchor="n" if portrait else "ne",
            justify="center" if portrait else "right",
            state="normal" if (not portrait or self.status_is_error) else "hidden",
        )
        self._set_coords(self.settings_item, 23, 22)

        self._draw_lyrics(width, height, frame)
        self._draw_progress(width, height, position, duration)
        self._configure_item(
            self.play_item,
            text="⏸" if playback and playback.is_playing else "▶",
        )

    def _hide_lyrics_image(self) -> None:
        self._lyrics_render_key = None
        self._configure_item(self.lyrics_image_item, state="hidden")

    def _update_lyrics_image(self, image, top: int) -> None:
        size = image.size
        if self._lyrics_photo is None or self._lyrics_photo_size != size:
            self._lyrics_photo = ImageTk.PhotoImage(image=image, master=self.root)
            self._lyrics_photo_size = size
            self.canvas.itemconfigure(
                self.lyrics_image_item,
                image=self._lyrics_photo,
                state="normal",
            )
            self._item_option_cache.setdefault(self.lyrics_image_item, {}).update(
                {"image": self._lyrics_photo, "state": "normal"}
            )
        else:
            # Reuse the same Tcl image object. This avoids allocation/garbage
            # collection spikes while a transition is in progress.
            self._lyrics_photo.paste(image)
            self._configure_item(self.lyrics_image_item, state="normal")
        self._set_coords(self.lyrics_image_item, 0, top)

    def _draw_lyrics(self, width: int, height: int, frame) -> None:
        if not self.document:
            self._hide_lyrics_image()
            message = "Cerco il testo sincronizzato…" if self.playback else "Avvia un brano su Spotify"
            self._set_coords(self.empty_item, width / 2, height * 0.46)
            self._configure_item(
                self.empty_item,
                text=message,
                state="normal",
                width=int(width * 0.72),
            )
            return
        if self.document.instrumental:
            self._hide_lyrics_image()
            self._set_coords(self.empty_item, width / 2, height * 0.46)
            self._configure_item(self.empty_item, text="Brano strumentale", state="normal")
            return
        if not self.document.lines:
            self._hide_lyrics_image()
            self._set_coords(self.empty_item, width / 2, height * 0.46)
            self._configure_item(
                self.empty_item,
                text="Testo sincronizzato\nnon disponibile",
                state="normal",
            )
            return

        self._configure_item(self.empty_item, state="hidden")
        current_index = frame.current_index if frame.current_index is not None else -1
        portrait = height > width * 1.12
        active_size = max(
            23,
            min(
                54 if portrait else 48,
                int(
                    min(
                        height * (0.061 if portrait else 0.082),
                        width * (0.092 if portrait else 0.050),
                    )
                ),
            ),
        )
        active_size = max(9, int(active_size * float(self.settings.get("font_scale", 1.0))))
        fade_strength = float(self.settings.get("fade_strength", 1.0))

        # Outside the short transition window the lyric panel is static. During
        # a transition, 1/4096 progress steps are finer than a display sub-pixel
        # and prevent unnecessary duplicate composites.
        progress_key = (
            0
            if frame.transition_progress <= 0.0
            else int(round(float(frame.transition_progress) * 4096.0))
        )
        karaoke_key = (
            int(round(float(frame.line_progress) * 2048.0))
            if frame.karaoke_eligible
            else 0
        )
        render_key: tuple[object, ...] = (
            id(self.document),
            current_index,
            progress_key,
            karaoke_key,
            frame.karaoke_eligible,
            width,
            height,
            active_size,
            round(fade_strength, 3),
        )
        if render_key == self._lyrics_render_key:
            return

        rendered = self.lyrics_renderer.render(
            self.document,
            current_index,
            float(frame.transition_progress),
            line_progress=float(frame.line_progress),
            karaoke_eligible=bool(frame.karaoke_eligible),
            width=width,
            height=height,
            active_size=active_size,
            fade_strength=fade_strength,
            portrait=portrait,
        )
        self._update_lyrics_image(rendered.image, rendered.top)
        self._lyrics_render_key = render_key

    def _draw_progress(self, width: int, height: int, position: float, duration: float) -> None:
        portrait = height > width * 1.12
        left, right = width * 0.095, width * 0.905
        y = height * (0.805 if portrait else 0.775)
        bar_height = max(4, int(height * 0.009))
        progress = min(max(position / duration, 0.0), 1.0) if duration > 0 else 0.0
        fill_right = left + (right - left) * progress
        self._set_coords(self.progress_track, left, y, right, y + bar_height)
        self._set_coords(self.progress_fill, left, y, fill_right, y + bar_height)
        radius = max(5, int(bar_height * 1.35))
        self._set_coords(
            self.progress_knob,
            fill_right - radius,
            y + bar_height / 2 - radius,
            fill_right + radius,
            y + bar_height / 2 + radius,
        )
        time_y = y + max(17, height * 0.032)
        self._set_coords(self.elapsed_item, left, time_y)
        self._set_coords(self.remaining_item, right, time_y)
        timer_font = self._font("Segoe UI", max(8, int(height * 0.020)))
        self._configure_item(
            self.elapsed_item,
            text=format_clock(position),
            font=timer_font,
        )
        self._configure_item(
            self.remaining_item,
            text="-" + format_clock(max(0.0, duration - position)),
            font=timer_font,
        )
        control_y = height * (0.925 if portrait else 0.895)
        self._set_coords(self.previous_item, width * (0.33 if portrait else 0.42), control_y)
        self._set_coords(self.play_item, width * 0.50, control_y)
        self._set_coords(self.next_item, width * (0.67 if portrait else 0.58), control_y)

    @staticmethod
    def _smoothstep(value: float) -> float:
        value = min(max(float(value), 0.0), 1.0)
        return value * value * (3.0 - 2.0 * value)

    @staticmethod
    def _interpolate(value: float, points) -> float:
        if value <= points[0][0]:
            return points[0][1]
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            if value <= x1:
                fraction = (value - x0) / max(0.0001, x1 - x0)
                return y0 + (y1 - y0) * fraction
        return points[-1][1]

    def toggle_play(self) -> None:
        if self.mode == "demo":
            if not self.playback:
                return
            position = self.playback.estimated_position()
            self.playback = PlaybackState(self.playback.track, position, not self.playback.is_playing)
            return
        if not self.playback:
            return
        action = "pause" if self.playback.is_playing else "play"
        if self.mode == "windows_media":
            self._windows_media_control(action)
        else:
            self._spotify_control(action)

    def previous(self) -> None:
        if self.mode == "demo":
            if self.playback:
                self.playback = PlaybackState(self.playback.track, 0.0, self.playback.is_playing)
            return
        if self.mode == "windows_media":
            self._windows_media_control("previous")
        else:
            self._spotify_control("previous")

    def next(self) -> None:
        if self.mode == "demo":
            if self.playback:
                position = min(self.playback.track.duration - 0.1, self.playback.estimated_position() + 10)
                self.playback = PlaybackState(self.playback.track, max(0, position), self.playback.is_playing)
            return
        if self.mode == "windows_media":
            self._windows_media_control("next")
        else:
            self._spotify_control("next")

    def _windows_media_control(self, action: str) -> None:
        def worker() -> None:
            try:
                if self.windows_media is None:
                    raise WindowsMediaError("Controllo multimediale Windows non inizializzato")
                getattr(self.windows_media, action)()
                self.event_queue.put(("control_done", f"Spotify locale: {action}"))
                time.sleep(0.25)
                self.event_queue.put(("playback", self.windows_media.current_playback()))
            except Exception as exc:
                self.event_queue.put(("error_nonfatal", str(exc)))

        threading.Thread(target=worker, name=f"WindowsMedia-{action}", daemon=True).start()

    def _spotify_control(self, action: str) -> None:
        def worker() -> None:
            try:
                assert self.spotify is not None
                getattr(self.spotify, action)()
                self.event_queue.put(("control_done", f"Spotify: {action}"))
                time.sleep(0.35)
                self.event_queue.put(("playback", self.spotify.current_playback()))
            except Exception as exc:
                self.event_queue.put(("error_nonfatal", str(exc)))

        threading.Thread(target=worker, name=f"Spotify-{action}", daemon=True).start()

    def open_lrc(self) -> None:
        path = filedialog.askopenfilename(
            parent=self.root,
            title="Apri testo sincronizzato",
            filetypes=[("Testi LRC", "*.lrc"), ("Tutti i file", "*.*")],
        )
        if not path:
            return
        try:
            document = parse_lrc_file(path)
        except Exception as exc:
            messagebox.showerror(APP_NAME, f"File LRC non valido:\n{exc}", parent=self.root)
            return
        self._stop_spotify_poll()
        self.playback_reconciler.reset()
        self.mode = "demo"
        self.document = document
        track = Track(
            title=document.track_title,
            artists=[document.artist_name],
            album=document.album_name,
            duration=document.duration,
            track_id=f"local:{Path(path).name}",
        )
        self.playback = PlaybackState(track, 0.0, True)
        self.status_message = f"File locale: {Path(path).name}"
        self.status_is_error = False

    def open_settings(self, connect_after_save: bool = False) -> None:
        dialog = tk.Toplevel(self.root)
        dialog.title("Impostazioni LyriCar")
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.resizable(False, False)
        frame = ttk.Frame(dialog, padding=18)
        frame.grid(sticky="nsew")

        client_id = tk.StringVar(value=str(self.settings.get("spotify_client_id", "")))
        redirect = tk.StringVar(value=str(self.settings.get("spotify_redirect_uri", "")))
        offset = tk.DoubleVar(value=float(self.settings.get("lyrics_offset", 0.0)))
        font_scale = tk.DoubleVar(value=float(self.settings.get("font_scale", 1.0)))
        fade = tk.DoubleVar(value=float(self.settings.get("fade_strength", 1.0)))
        animation = tk.DoubleVar(value=float(self.settings.get("animation_seconds", 0.55)))

        ttk.Label(frame, text="Spotify Web API Client ID (opzionale)").grid(row=0, column=0, sticky="w")
        ttk.Entry(frame, textvariable=client_id, width=48).grid(row=1, column=0, columnspan=3, sticky="ew", pady=(2, 10))
        ttk.Label(frame, text="Redirect URI Web API").grid(row=2, column=0, sticky="w")
        ttk.Entry(frame, textvariable=redirect, width=48).grid(row=3, column=0, columnspan=3, sticky="ew", pady=(2, 12))

        ttk.Label(frame, text="Offset lyrics (s)").grid(row=4, column=0, sticky="w")
        ttk.Scale(frame, from_=-3.0, to=3.0, variable=offset, orient="horizontal", length=250).grid(row=5, column=0, columnspan=2, sticky="ew")
        ttk.Label(frame, textvariable=offset, width=6).grid(row=5, column=2)

        ttk.Label(frame, text="Dimensione testo").grid(row=6, column=0, sticky="w", pady=(10, 0))
        ttk.Scale(frame, from_=0.75, to=1.35, variable=font_scale, orient="horizontal", length=250).grid(row=7, column=0, columnspan=2, sticky="ew")
        ttk.Label(frame, textvariable=font_scale, width=6).grid(row=7, column=2)

        ttk.Label(frame, text="Intensità dissolvenza").grid(row=8, column=0, sticky="w", pady=(10, 0))
        ttk.Scale(frame, from_=0.65, to=1.5, variable=fade, orient="horizontal", length=250).grid(row=9, column=0, columnspan=2, sticky="ew")
        ttk.Label(frame, textvariable=fade, width=6).grid(row=9, column=2)

        ttk.Label(frame, text="Durata transizione (s)").grid(row=10, column=0, sticky="w", pady=(10, 0))
        ttk.Scale(frame, from_=0.25, to=1.2, variable=animation, orient="horizontal", length=250).grid(row=11, column=0, columnspan=2, sticky="ew")
        ttk.Label(frame, textvariable=animation, width=6).grid(row=11, column=2)

        def save(and_connect: bool = False) -> None:
            value = client_id.get().strip()
            redirect_value = redirect.get().strip()
            if and_connect and not value:
                messagebox.showerror(APP_NAME, "Inserisci lo Spotify Client ID.", parent=dialog)
                return
            self.settings.update(
                {
                    "spotify_client_id": value,
                    "spotify_redirect_uri": redirect_value,
                    "lyrics_offset": round(offset.get(), 3),
                    "font_scale": round(font_scale.get(), 3),
                    "fade_strength": round(fade.get(), 3),
                    "animation_seconds": round(animation.get(), 3),
                    "render_engine_version": 3,
                }
            )
            self._save_settings()
            self._lyrics_render_key = None
            self.lyrics_renderer.clear()
            self._configure_spotify_client()
            dialog.destroy()
            if connect_after_save or and_connect:
                self.connect_spotify(start_live_after=True)

        button_row = ttk.Frame(frame)
        button_row.grid(row=12, column=0, columnspan=3, sticky="ew", pady=(18, 0))
        ttk.Button(button_row, text="Spotify locale", command=lambda: (dialog.destroy(), self.use_windows_media())).pack(side="left")
        ttk.Button(button_row, text="Annulla", command=dialog.destroy).pack(side="right", padx=(8, 0))
        ttk.Button(button_row, text="Salva", command=save).pack(side="right", padx=(8, 0))
        ttk.Button(button_row, text="Salva e collega Web API", command=lambda: save(True)).pack(side="right")
        dialog.bind("<Return>", lambda _event: save())
        dialog.bind("<Escape>", lambda _event: dialog.destroy())

    def toggle_fullscreen(self) -> None:
        self.fullscreen = not self.fullscreen
        self.root.attributes("-fullscreen", self.fullscreen)
        self.root.config(menu="" if self.fullscreen else self.menu)

    def exit_fullscreen(self) -> None:
        if self.fullscreen:
            self.fullscreen = False
            self.root.attributes("-fullscreen", False)
            self.root.config(menu=self.menu)

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        self.stop_poll.set()
        if self._frame_after_id is not None:
            try:
                self.root.after_cancel(self._frame_after_id)
            except tk.TclError:
                pass
            self._frame_after_id = None
        if self.windows_media is not None:
            self.windows_media.close()
        self.lyrics_renderer.close()
        self.root.destroy()


def main() -> int:
    parser = argparse.ArgumentParser(description="LyriCar Windows renderer and Spotify test client")
    parser.add_argument("--spotify-client-id", help="Override the saved Spotify Client ID")
    parser.add_argument("--fullscreen", action="store_true", help="Start in fullscreen mode")
    parser.add_argument(
        "--mode",
        choices=("demo", "windows_media", "spotify"),
        default="demo",
        help="Initial playback source",
    )
    parser.add_argument(
        "--profile",
        choices=sorted(DISPLAY_PROFILES),
        help="Select a display profile for this run",
    )
    args = parser.parse_args()

    root = tk.Tk()
    app = LyriCarPreview(root, client_id_override=args.spotify_client_id)
    if args.profile:
        app.apply_display_profile(args.profile)
    if args.mode == "windows_media":
        root.after(100, app.use_windows_media)
    elif args.mode == "spotify":
        root.after(100, app.use_spotify)
    if args.fullscreen:
        root.after(50, app.toggle_fullscreen)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
