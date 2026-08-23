# LyriCar — avvio da Windows

## 1. Prova immediata con Spotify — metodo consigliato

Non serve alcun Client ID.

1. Chiudi l'eventuale Preview già aperta.
2. Fai doppio clic su `AVVIA_CON_SPOTIFY.bat` nella cartella principale del pacchetto, oppure su `WindowsPreview\run_spotify_locale.bat`.
3. Al primo avvio il file installa automaticamente Windows Media Control e il renderer grafico Pillow necessari. L'installazione avviene una sola volta.
4. LyriCar prova ad aprire Spotify Desktop; se Windows non dispone dell'app, usa normalmente il Web Player.
5. Avvia una canzone in Spotify.
6. LyriCar rileva titolo, artista, durata, posizione, play/pausa e cambio brano tramite la sessione multimediale di Windows.
7. Il testo sincronizzato viene cercato automaticamente su LRCLIB.

Il renderer approvato nella versione `0.1.5-alpha.6`, conservato nel pacchetto `0.2.0-alpha.7`, mantiene l'orologio continuo della revisione precedente e sostituisce la scalatura dei font Tk con un compositore sub-pixel. Le righe vengono prerenderizzate, preparate prima del cambio e scalate a quarti di pixel; anche impostando la transizione a 1,2 secondi non devono più comparire i gradini della vecchia animazione. Un vero spostamento nella timeline di Spotify continua a essere applicato subito.

Questa è la modalità più vicina all'integrazione già usata in Toastify e non richiede Dashboard Spotify, Client ID, Client Secret o callback OAuth.

## 2. Provare soltanto il renderer demo

1. Fai doppio clic su `AVVIA_DEMO.bat`, oppure apri la cartella `WindowsPreview` e avvia `run_preview.bat`.
2. La finestra usa il preset logico verticale **600×800** per rappresentare il display Easy Link da 9,3".
3. La diagonale non determina la risoluzione reale; il layout è proporzionale e si adatterà alla superficie fornita da CarPlay.

Comandi principali:

- `F11`: schermo intero;
- `Esc`: esce dallo schermo intero;
- `Spazio`: play/pausa;
- frecce sinistra/destra: precedente/successivo;
- `Ctrl+L`: carica un file `.lrc`;
- `Visualizza → Profilo display`: passa tra Renault 9,3" verticale e CarPlay generico orizzontale.

## 3. Metodo Spotify Web API — opzionale

Il collegamento tramite Client ID rimane disponibile come percorso alternativo:

1. Apri **Spotify → Apri Dashboard sviluppatori**.
2. Crea o apri l'app developer `LyriCar`.
3. Registra esattamente `http://127.0.0.1:8765/callback` come Redirect URI.
4. Copia il Client ID; il Client Secret non serve.
5. In LyriCar apri **Visualizza → Impostazioni** e premi **Salva e collega Web API**.
6. Completa il consenso nel browser.

Se Windows non apre il browser, l'ultimo URL OAuth viene salvato in `%LOCALAPPDATA%\LyriCar\spotify_authorization_url.txt`.

## 4. Ottenere EXE e IPA senza Mac locale

1. Carica il repository in GitHub tramite GitHub Desktop.
2. Il secret `SPOTIFY_CLIENT_ID` è facoltativo: sull’iPhone il Client ID può essere inserito direttamente nell’app.
3. Avvia il workflow **CI** e verifica che i job siano verdi.
4. Avvia **Build distributables**.
5. Scarica dagli artifact l’EXE Windows e, per la prima prova, `LyriCar-standard-unsigned-IPA`.

L'IPA deve essere firmata con il metodo personale di sideload prima dell'installazione su iPhone.

## 5. Fullscreen CarPlay

La build standard usa la Live Activity. Il renderer `CPWindow` fullscreen è incluso come proof of concept, ma richiede un entitlement navigation realmente concesso da Apple e non è attivo nella configurazione standard.
