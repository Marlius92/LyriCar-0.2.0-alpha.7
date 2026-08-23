# LyriCar Preview per Windows

Simulatore desktop del renderer LyriCar. Dispone di quattro modalità:

1. **Spotify locale senza Client ID**, tramite Windows Media Control/GSMTC;
2. Spotify Web API con Client ID, opzionale;
3. demo locale inclusa;
4. file `.lrc` scelto dall'utente.

La revisione `0.1.5-alpha.6` non anima più direttamente i font di Tk. Le righe vengono prerenderizzate con Pillow, scalate a quarti di pixel e composte in un solo pannello RGB riutilizzabile. Questo elimina i gradini visibili della precedente quantizzazione a 2 punti, soprattutto quando la durata viene portata a 1,2 secondi. La sincronizzazione Spotify non è stata modificata.

## Spotify locale — consigliato

Avvia:

```text
run_spotify_locale.bat
```

Al primo avvio vengono installati automaticamente il binding WinRT e il renderer Pillow necessari. LyriCar apre Spotify, legge la sessione multimediale attiva e controlla play, pausa, precedente e successivo senza OAuth.

Dall'interfaccia puoi attivare la stessa modalità con:

```text
Modalità → Spotify locale — senza Client ID
```

## Demo Renault Clio 9,3"

Avvia:

```text
run_preview.bat
```

La Preview usa una sagoma logica verticale 600×800 per riprodurre il rapporto del display; non presume che questa sia la risoluzione nativa del pannello.

## Comandi

- `F11`: schermo intero;
- `Esc`: esce dallo schermo intero;
- `Spazio`: play/pausa;
- freccia sinistra: precedente;
- freccia destra: successivo;
- `Ctrl+L`: carica un file `.lrc`.

## Spotify Web API — opzionale

Registra `http://127.0.0.1:8765/callback` nel Dashboard Spotify, inserisci il Client ID nelle impostazioni e seleziona **Salva e collega Web API**. Il token viene salvato in `%LOCALAPPDATA%\LyriCar\spotify_token.json`.

## EXE

```powershell
powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
```
