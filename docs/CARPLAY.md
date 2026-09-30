# CarPlay

LyriCar mantiene due percorsi completamente separati.

## 1. Build standard: Live Activity

Il target `LyriCar` non dichiara una scena CarPlay app e non richiede un entitlement CarPlay specifico. Pubblica invece una Live Activity ottimizzata per `ActivityFamily.small`, la famiglia usata da CarPlay per un layout personalizzato.

Il layout CarPlay privilegia i lyrics:

- titolo e artista discreti;
- due righe precedenti;
- riga corrente grande;
- due righe successive;
- indicatore play/pausa.

La Live Activity viene preparata mentre LyriCar è ancora in primo piano. In questo modo l'utente può passare a Spotify e collegare CarPlay mantenendo un'attività già esistente, che iOS può aggiornare anche durante l'esecuzione in background. Le transizioni vengono inviate solo quando cambia la finestra dei lyrics o lo stato di riproduzione; non viene tentato un refresh per-frame.

Da iOS 26 il sistema può presentare una Live Activity anche nella Dashboard/Home di CarPlay. Dimensione, posizione e disponibilità restano controllate da iOS; non è fullscreen.

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
2. aprire LyriCar almeno una volta con Live Activity attiva, così l'attività viene preparata in primo piano;
3. verificare la modalità demo sul Lock Screen: la riga corrente deve avanzare automaticamente;
4. aprire Spotify originale e avviare un brano;
5. collegare CarPlay e verificare la Live Activity nella Dashboard/Home;
6. controllare che le cinque righe avanzino a ogni timestamp LRCLIB;
7. soltanto dopo, studiare firma ed entitlement del target sperimentale.

Il renderer, il motore lyrics e Spotify non dipendono dal metodo CarPlay: cambiare il percorso di visualizzazione non richiede di riscrivere il resto dell’app.
