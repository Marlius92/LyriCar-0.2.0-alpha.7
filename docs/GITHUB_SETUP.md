# Pubblicazione e build da Windows con GitHub

## 1. Caricamento

1. Estrai LyriCar in una cartella nuova.
2. Apri GitHub Desktop.
3. Seleziona **File → Add local repository**.
4. Crea il repository locale se richiesto.
5. Pubblicalo su GitHub.

`Config/Secrets.local.xcconfig` è escluso dal repository. Dalla versione 0.2.0 non è necessario creare questo file: il Client ID può essere inserito direttamente nell’app.

## 2. CI

Apri:

```text
Actions → CI → Run workflow
```

Il workflow esegue:

- test Swift del core;
- test Python della Preview;
- build iOS Simulator della app standard;
- build iOS Simulator della app CarPlay sperimentale.

Il job iOS usa il runner `xcode-27`.

## 3. Artefatti

Apri:

```text
Actions → Build distributables → Run workflow
```

Vengono prodotti:

- `LyriCar-Preview-Windows`;
- `LyriCar-standard-unsigned-IPA`;
- `LyriCar-carplay-experimental-unsigned-IPA`.

Per la prima prova usa **LyriCar standard**. L’IPA deve essere firmata con il proprio metodo di sideload.

## 4. Client ID Spotify opzionale come secret

Il Client ID può essere digitato nell’app. Per preconfigurarlo nella build, crea comunque il secret:

```text
Settings → Secrets and variables → Actions → New repository secret
```

Nome:

```text
SPOTIFY_CLIENT_ID
```

Il Client ID non è un Client Secret, ma il secret GitHub evita di inserirlo nei log o nel repository.

## 5. Fullscreen sperimentale

La CI può compilare il target sperimentale senza firma. Non può concedere l’entitlement CarPlay navigation. Per una prova reale servono:

- App ID abilitato;
- provisioning profile contenente `com.apple.developer.carplay-maps`;
- firma coerente;
- CarPlay Simulator o automobile reale.
