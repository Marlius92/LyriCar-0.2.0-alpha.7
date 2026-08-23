# AGENTS.md — Project LyriCar

## Obiettivo permanente

LyriCar è un'app iOS privata pensata per visualizzare, principalmente su CarPlay, i lyrics sincronizzati del brano già riprodotto da Spotify. Non deve duplicare ricerca, playlist, libreria, coda o riproduzione: Spotify resta il player.

## UI vincolante

- titolo e artista discreti in alto;
- cinque righe: `-2`, `-1`, `0`, `+1`, `+2`;
- riga `0` molto grande e luminosa;
- `-1/+1` più piccole e attenuate;
- `-2/+2` ancora più piccole e sfumate;
- transizione fluida con profondità/dissolvenza bidirezionale nello stile concettuale di Lyrics Plus;
- barra di avanzamento;
- tempo trascorso e restante;
- controlli precedente, play/pausa, successivo;
- sfondo scuro, nessun elemento superfluo.

## Architettura vincolante

Spotify, lyrics, sync e renderer devono restare separati. Il renderer non deve dipendere dal metodo usato per portarlo su CarPlay. Preview Windows, iPhone, Live Activity e `CPWindow` condividono lo stesso modello concettuale.

## Stato 0.2.0-alpha.7

M0–M5 sono implementate nel sorgente. La transizione Windows 0.1.5-alpha.6 è stata approvata dall’utente e resta congelata come base stabile. La revisione 0.2.0-alpha.7 aggiunge modalità demo iPhone, Client ID Spotify configurabile nell’app e build standard/sperimentale separate. Spotify locale Windows usa GSMTC con compensazione `LastUpdatedTime` e un orologio riconciliato anti-arretramento. La Preview Windows usa ora un compositore Pillow sub-pixel: glifi ad alta risoluzione, scala a quarti di pixel, pre-riscaldamento della transizione e upload RGB riutilizzabile. Il renderer SwiftUI mantiene il percorso nativo a 60 Hz e usa la stessa curva di movimento ammorbidita. La build iOS completa deve essere verificata tramite GitHub Actions/Xcode. Il fullscreen CarPlay richiede l'entitlement navigation Apple ed è un proof of concept; la Live Activity è il fallback supportato.

## Regole per i prossimi interventi

1. Non trasformare LyriCar in un player o gestore di playlist.
2. Non rimuovere la Preview Windows.
3. Non legare il core all'hack/target CarPlay.
4. Non inserire Client ID, token o segreti nel repository.
5. Mantenere test e documentazione aggiornati.
6. Dichiarare con precisione ciò che è testato e ciò che è soltanto implementato.
7. Prima di usare API Spotify/Apple correnti, verificare la documentazione ufficiale aggiornata.
