# Milestone M0–M5

## M0 — Renderer

**Stato: approvata.**

- Preview Windows ridimensionabile e fullscreen.
- Preset Renault Clio Easy Link 9,3" verticale, sagoma logica 600×800.
- Preset CarPlay generico 800×480.
- Cinque righe con scala, opacità, profondità e movimento continuo.
- Titolo, artista, barra, tempi e controlli.
- Caricamento `.lrc` locale e demo inclusa.
- Compositore Pillow sub-pixel con scala a quarti di pixel.

Criterio raggiunto: l’utente ha confermato che la transizione `0.1.5-alpha.6` è perfetta.

## M1 — Lyrics engine

**Stato: implementata e testata.**

- Parser `[mm:ss.xx]`, `[hh:mm:ss.xxx]`, timestamp multipli e tag offset.
- Ricerca esatta LRCLIB e fallback search.
- Ranking per titolo, artista, album e durata.
- Retry su 429 e 5xx.
- Cache positiva e negativa.
- Offset utente.
- Selezione binaria della riga corrente.
- Seek, pausa, cambio traccia e finestra di transizione.

Criterio raggiunto: test automatici verdi e risultato deterministico.

## M2 — Spotify

**Stato: implementata; prova iPhone ancora necessaria.**

- Authorization Code con PKCE, senza Client Secret nell’app.
- Client ID configurabile a runtime.
- Callback standard `lyricar-login://callback`.
- Callback sperimentale `lyricar-exp-login://callback`.
- Callback loopback separata per la Preview Windows Web API.
- Token nel Keychain e refresh automatico.
- Lettura Now Playing.
- `PlaybackClock`/`PlaybackReconciler` anti-arretramento.
- Compensazione `LastUpdatedTime` su Windows.
- Play, pausa, precedente e successivo.
- Gestione 204, 401, 403, 404, 429 e 5xx.

Criterio architetturale raggiunto: LyriCar non gestisce playlist, libreria o coda.

## M3 — App iPhone

**Stato: candidata alla prima build Xcode.**

- Interfaccia SwiftUI fullscreen.
- Renderer a 60 Hz con curva continua.
- Modalità demo senza Spotify e senza audio.
- Onboarding con Client ID inseribile, Redirect URI visibile e collegamento PKCE.
- Impostazioni per offset, dimensione, dissolvenza e durata transizione.
- Cache, disconnessione e sostituzione della configurazione Spotify.
- Privacy manifest.
- Drive Mode opzionale.
- Supporto portrait e landscape.
- Icona LyriCar.

Criterio successivo: CI Xcode 27 verde, firma e installazione della IPA standard su iPhone.

## M4 — CarPlay

**Stato: due percorsi separati.**

### Build standard

- ActivityKit + widget extension.
- Layout `ActivityFamily.small` dedicato alla Dashboard CarPlay.
- Titolo, artista, riga corrente/successiva e progressione.
- Nessun entitlement navigation non concesso.

### Build sperimentale

- Scena `CPTemplateApplicationScene`.
- `CPMapTemplate` radice.
- `CPWindow` con il renderer SwiftUI LyriCar.
- Bundle ID, callback e IPA separati.
- Entitlement `com.apple.developer.carplay-maps` isolato nel target sperimentale.

Criterio standard: verificare la Live Activity su iPhone e CarPlay.  
Criterio sperimentale: test possibile soltanto con provisioning realmente compatibile.

## M5 — Stabilità e consegna

**Stato locale: completata; validazione Apple esterna ancora necessaria.**

- 17 test Swift.
- 20 test Python.
- Test per timestamp quantizzati, pausa, seek, scala sub-pixel, prerendering e curva.
- Validazione sintattica Swift.
- CI multipiattaforma.
- Workflow per EXE Windows e due IPA non firmate.
- Gestione errori, fallback, privacy e documentazione.

Criterio locale raggiunto: core, Preview e struttura repository validati.  
Criterio finale: build Xcode, installazione iPhone, login Spotify e prova CarPlay reale.
