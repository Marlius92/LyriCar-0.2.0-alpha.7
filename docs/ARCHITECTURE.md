# Architettura di LyriCar

## Flusso principale

```text
Spotify Web API / Windows Media Control / Demo locale
  │ titolo, artista, ID, durata, posizione grezza, stato
  ▼
PlaybackSnapshot
  ▼
PlaybackClock / PlaybackReconciler
  │ interpolazione continua, filtro campioni obsoleti, seek reali
  │
  ├── LyricsRepository ── LRCLIB ── cache hit/miss
  │
  ▼
LyricsSyncEngine
  │ riga -2 / -1 / 0 / +1 / +2, progressione riga, transizione
  ▼
Renderer LyriCar
  ├── SwiftUI iPhone
  ├── Live Activity
  ├── CPWindow sperimentale
  └── Preview Windows equivalente
```

## Separazione delle responsabilità

### `LyriCarCore`

Codice Swift senza dipendenza da UIKit, SwiftUI, Spotify o CarPlay. Contiene modelli, parser LRC, client LRCLIB, cache, ranking, `PlaybackClock`, interpolazione e sincronizzazione. È verificabile anche su Linux tramite Swift Package Manager.

### `SpotifyConfigurationStore`

Legge la callback dal bundle del target corrente e conserva localmente il Client ID inserito dall’utente. Il Client ID può essere sostituito senza ricompilare l’IPA. La build standard usa `lyricar-login://callback`; quella sperimentale usa `lyricar-exp-login://callback`.

### `SpotifyAuthController` e `SpotifyWebAPI`

Implementano Authorization Code con PKCE, conservano i token nel Keychain, rinnovano l’access token e interrogano `/v1/me/player`. Espongono soltanto lo stato standardizzato e i quattro comandi necessari: precedente, play, pausa e successivo.

### `AppModel`

Coordina autenticazione, polling Spotify, modalità demo, riconciliazione dei campioni tramite `PlaybackClock`, cambio brano, ricerca lyrics, cache, Live Activity e Drive Mode. La UI non effettua direttamente chiamate di rete.

### `LyriCarDemo`

Permette di aprire l’IPA e collaudare renderer, barra, tempi e controlli prima di configurare Spotify. Non riproduce audio e usa testo originale incluso nel repository.

### `LyriCarLyricsView`

È il renderer iOS unico. Calcola localmente la posizione tra i polling Spotify, quindi progress bar e transizioni continuano a 60 Hz. Le righe sono posizionate tramite una distanza relativa continua: durante il passaggio la riga `+1` converge al centro mentre la riga corrente sale verso `-1`.

### `WindowsPreview`

Replica la stessa matematica in Python/Tkinter. La modalità locale legge GSMTC, compensa l’età del campione con `LastUpdatedTime` e passa gli aggiornamenti a `PlaybackReconciler`, evitando regressioni visive. Il renderer Pillow sub-pixel approvato nella versione `0.1.5-alpha.6` resta congelato funzionalmente.

## Isolamento delle build iOS

### Target `LyriCar`

È la build da installare per prima. Compila app iPhone, core e Live Activity, ma esclude completamente la cartella `LyriCarApp/CarPlay` e usa un file entitlement vuoto. Un errore o un permesso mancante del proof of concept fullscreen non può quindi bloccare l’app standard.

### Target `LyriCarExperimental`

Compila anche `CarPlaySceneDelegate`, usa `Info-CarPlay.plist` e dichiara l’entitlement navigation sperimentale. Produce un’IPA separata con Bundle ID, widget e callback Spotify distinti.

## CarPlay

Due renderer condividono gli stessi dati:

1. **Live Activity:** percorso supportato dal sistema, con layout `ActivityFamily.small` dedicato alla Dashboard; non è fullscreen.
2. **`CPWindow`:** target sperimentale di navigation app con `CPMapTemplate` radice e `UIHostingController`; richiede entitlement e provisioning effettivamente compatibili.

Il core non dipende da nessuno dei due metodi. Cambiare il percorso fullscreen non richiede di rifare Spotify, LRCLIB, sincronizzazione o UI iPhone.
