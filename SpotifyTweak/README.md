# LyriCar Spotify Tweak

Experimental CarPlay-only companion injected into Spotify.

## Goal

Add a **Lyrics** button to Spotify's existing CarPlay Now Playing template without replacing Spotify's playback UI.

This module does **not** unlock Spotify Premium, remove ads, bypass DRM, or modify subscription features.

## Milestone 0.2.0 — synchronized lyrics

When Spotify is connected to CarPlay, the tweak:

1. discovers Spotify's existing `CPTemplateApplicationScene`;
2. obtains its public `CPInterfaceController`;
3. appends a custom `CPNowPlayingImageButton` to `CPNowPlayingTemplate.sharedTemplate`;
4. opens a `CPListTemplate` named **Lyrics** when the button is pressed;
5. reads current title, artist, album, duration and playback position from `MPNowPlayingInfoCenter`;
6. queries LRCLIB for `syncedLyrics`;
7. parses LRC timestamps;
8. displays two previous lines, the highlighted current line, and two upcoming lines;
9. advances the active line automatically while playback continues;
10. detects track changes while the Lyrics page is open and loads the new song automatically.

The CarPlay page deliberately updates at line level rather than attempting LyriCar's 60 fps per-character renderer. `CPListTemplate` is intended for template-based CarPlay UI, so row-level synchronized updates are the safer first implementation.

## Layout

The Lyrics page is approximately:

```text
Song title — Artist
previous -2
previous -1
▶ CURRENT LINE
next +1
next +2
```

If LRCLIB has no timestamped lyrics, the page reports that explicitly instead of showing stale text.

## Why this approach

It avoids hard-coding Spotify private class names. The tweak uses public CarPlay objects that already exist inside Spotify's process, which should make the integration less sensitive to Spotify app updates.

## Build

Requires Theos on macOS:

```sh
cd SpotifyTweak
make clean package FINALPACKAGE=1
```

The resulting package is placed in `SpotifyTweak/packages/`. The tweak dylib is also generated under Theos' build output and can be used by an IPA patch/injection workflow.

## Target

The package filter targets Spotify's normal bundle identifier:

`com.spotify.client`

For sideloaded Spotify, the dylib should be injected directly into the Spotify application binary; this avoids depending on the post-signing bundle identifier used by a signer.

## Test milestone

The real-device test should verify:

- Spotify launches after signing;
- Spotify appears normally in CarPlay;
- the Lyrics button appears in Now Playing;
- pressing it opens the Lyrics template;
- LRCLIB returns the current song;
- the highlighted line advances with playback;
- pause/seek/track changes do not leave stale lyrics on screen.

After this is confirmed on real CarPlay we can evaluate a more aggressive Spotify-CarPlay UI hook for finer-grained karaoke effects.
