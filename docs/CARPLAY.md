# CarPlay

LyriCar mantiene due percorsi completamente separati.

## 1. Build standard: Live Activity

Il target `LyriCar` non dichiara una scena CarPlay app e non richiede un entitlement CarPlay specifico. Pubblica invece una Live Activity con:

- titolo e artista;
- riga corrente;
- riga successiva;
- stato play/pausa;
- avanzamento.

Da iOS 26 il sistema può presentare una Live Activity anche in CarPlay. Dimensione, posizione e disponibilità restano controllate da iOS; non è fullscreen.

## 2. Build sperimentale: CPWindow fullscreen

Il target `LyriCarExperimental` contiene:

- `CPTemplateApplicationScene`;
- `CPMapTemplate` come root template;
- `CPWindow`;
- `UIHostingController` con `LyriCarLyricsView`;
- entitlement `com.apple.developer.carplay-maps`.

Il codice è isolato dalla build standard e può essere compilato separatamente. Il sistema non è però obbligato ad avviare la scena: il provisioning profile deve contenere l’entitlement navigation concesso da Apple.

Inoltre Apple destina la finestra delle app di navigazione al rendering della mappa. LyriCar la tratta quindi come proof of concept privato, non come percorso ufficialmente supportato per i lyrics.

## Ordine dei test

1. installare LyriCar standard;
2. verificare modalità demo e Spotify su iPhone;
3. verificare la Live Activity;
4. provare il comportamento con CarPlay reale;
5. soltanto dopo, studiare firma ed entitlement del target sperimentale.

Il renderer, il motore lyrics e Spotify non dipendono dal metodo CarPlay: cambiare il percorso di visualizzazione non richiede di riscrivere il resto dell’app.
