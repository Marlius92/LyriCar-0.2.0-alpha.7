# LyriCar 0.3.1-alpha.15 — Widget Sync Fix

Questa build corregge i problemi osservati sui widget CarPlay della 0.3.0-alpha.14.

## Correzioni

- Corretto il numero di versione reale dell'app e dell'estensione WidgetKit: ora Info.plist usa MARKETING_VERSION e CURRENT_PROJECT_VERSION, evitando che iOS continui a vedere la build come 0.2.0 (7).
- Stato widget condiviso in modo ridondante tramite App Group e Keychain condiviso, per rendere la comunicazione host app / estensione più robusta dopo la firma Signulous.
- Lo stato widget viene pubblicato immediatamente quando arriva un nuovo playback Spotify e quando termina il caricamento dei lyrics, oltre al ticker periodico.
- Aggiunto rilevamento passivo di CarPlay cablato/wireless tramite scena, route Car Audio e secondary screen fallback, utilizzabile anche dal target standard privo di entitlement CarPlay.
- La schermata Impostazioni mostra diagnostica aggiuntiva: CarPlay rilevato, trasporto Widget e brano Spotify corrente.

## Versione

- Marketing version: 0.3.1
- Build: 15
