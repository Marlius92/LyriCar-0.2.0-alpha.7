# LyriCar Spotify Tweak 0.2.0

- Replaces placeholder lyrics with real LRCLIB synchronized lyrics.
- Reads current Spotify title, artist, album, duration and playback position from `MPNowPlayingInfoCenter`.
- Parses timestamped LRC lyrics.
- Displays two previous lines, the current highlighted line and two following lines on CarPlay.
- Advances the highlighted line automatically during playback.
- Reloads lyrics automatically when the track changes while the Lyrics page is open.
- Shows explicit loading/not-found/error states instead of stale lyrics.

This release does not modify Spotify subscription/Premium behavior and does not implement per-character 60 fps karaoke on `CPListTemplate`.
