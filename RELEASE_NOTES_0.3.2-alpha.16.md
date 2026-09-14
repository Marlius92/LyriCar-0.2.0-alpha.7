# LyriCar 0.3.2-alpha.16 — Dual-App CarPlay Widgets

Questa build introduce una seconda app installabile, **LyriCar Companion**, per verificare l'uso simultaneo delle due raccolte widget di CarPlay.

## Layout previsto

- **LyriCar · Superiore**: tre righe passate (`-3`, `-2`, `-1`).
- **LyriCar Companion · Corrente**: riga corrente grande + due righe future (`+1`, `+2`).
- Nessuna barra di avanzamento, tempo o comando di riproduzione.

Le due app leggono lo stesso snapshot attraverso App Group e Keychain condivisi. Spotify e LRCLIB rimangono gestiti esclusivamente dall'app LyriCar principale.

La disposizione fisica dei due widget (verticale o laterale) resta controllata da CarPlay e dall'head unit.
