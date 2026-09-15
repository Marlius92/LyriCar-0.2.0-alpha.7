# CarPlay test plan

1. Sign the injected Spotify IPA without Duplicate App for the first validation.
2. Launch Spotify and start a track with known synchronized lyrics.
3. Connect to CarPlay and open Spotify Now Playing.
4. Verify the Lyrics button is visible.
5. Open Lyrics and confirm LRCLIB loading state changes to real lyrics.
6. Confirm the current row advances in sync with the song.
7. Pause and resume playback.
8. Seek forward/backward and verify the highlighted row follows the playback position.
9. Change track while the Lyrics page remains open and verify the new lyrics are loaded.
10. Test one song with no synced LRCLIB entry and verify an explicit not-available message is shown.
