# LyriCar 0.2.0-alpha.7 — iPhone First Run

Questa consegna porta il progetto dalla Preview Windows approvata alla prima prova iPhone.

## Cosa cambia

- demo iPhone immediata, senza Spotify;
- Client ID inseribile direttamente nell’app;
- login Spotify PKCE senza Client Secret;
- callback standard `lyricar-login://callback`;
- build standard isolata dal codice CarPlay sperimentale;
- seconda IPA separata per il proof of concept fullscreen;
- riavvio sicuro del polling dopo errori o riconnessioni;
- pipeline GitHub Xcode 27 pronta.

## Primo artifact da usare

Dopo il workflow **Build distributables**, scaricare:

```text
LyriCar-standard-unsigned-IPA
```

La build sperimentale CarPlay non è il primo test e non deve sostituire la standard.

## Ordine di prova

1. CI verde.
2. Build della IPA standard.
3. Firma e sideload.
4. Apertura della demo iPhone.
5. Configurazione Client ID e login Spotify.
6. Test dei controlli e della sincronizzazione.
7. Live Activity.
8. Solo successivamente, percorso CarPlay sperimentale.
