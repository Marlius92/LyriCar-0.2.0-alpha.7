# LyriCar Spotify Tweak

Experimental CarPlay-only companion injected into Spotify.

## Goal

Add a **Lyrics** button to Spotify's existing CarPlay Now Playing template without replacing Spotify's playback UI.

This module does **not** unlock Spotify Premium, remove ads, bypass DRM, or modify subscription features.

## Milestone 0.1.0

The first proof build deliberately has no network/lyrics provider dependency.

When Spotify is connected to CarPlay, the tweak:

1. discovers Spotify's existing `CPTemplateApplicationScene`;
2. obtains its public `CPInterfaceController`;
3. appends a custom `CPNowPlayingImageButton` to `CPNowPlayingTemplate.sharedTemplate`;
4. opens a `CPListTemplate` named **Lyrics** when the button is pressed;
5. shows the current title/artist from `MPNowPlayingInfoCenter` plus harmless placeholder lyric rows.

If this page appears on the vehicle display, the CarPlay injection path is proven. The next milestone will replace the placeholder rows with LRCLIB synchronized lyrics.

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

## Next milestone

After the button/page is confirmed on real CarPlay:

- read current track and playback clock from `MPNowPlayingInfoCenter`;
- query LRCLIB;
- parse synced LRC timestamps;
- update previous/current/next rows;
- add user-adjustable lyric offset;
- keep updates conservative for CarPlay templates rather than attempting the 60 fps renderer used by the LyriCar iPhone app.
