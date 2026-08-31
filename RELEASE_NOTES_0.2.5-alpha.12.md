# LyriCar 0.2.5-alpha.12 — Character Karaoke

- Karaoke highlight on the active lyric, progressing character by character.
- Highlight is enabled only when the current line has a real following timestamp.
- If timing data is missing, LyriCar keeps the approved static lyric rendering unchanged.
- Seek, pause and resume reuse the same monotonic playback clock, so the highlight follows the song position.
- Windows Preview mirrors the behaviour for local testing.
- Existing sub-pixel transition renderer and AppIcon packaging fix are preserved.
