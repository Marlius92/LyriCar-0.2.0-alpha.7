# LyriCar — prima prova iPhone partendo da Windows

Questa versione contiene due build iOS separate:

- **LyriCar standard**: è la prima IPA da installare. Include app iPhone, modalità demo, Spotify, Live Activity e renderer approvato. Non dichiara entitlement CarPlay non concessi.
- **LyriCar CarPlay experimental**: contiene anche la scena `CPWindow` fullscreen. Serve esclusivamente come proof of concept e non può ottenere il fullscreen senza un entitlement CarPlay navigation realmente presente nella firma.

## 1. Carica il progetto su GitHub

1. Estrai lo ZIP in una cartella nuova.
2. Apri GitHub Desktop.
3. Seleziona **File → Add local repository**.
4. Se necessario scegli **create a repository here**.
5. Pubblica il repository su GitHub.

Non è obbligatorio configurare un secret Spotify: il Client ID si può inserire direttamente dentro LyriCar dopo l’installazione.

## 2. Controlla la compilazione

Nel repository GitHub apri:

```text
Actions → CI → Run workflow
```

Devono diventare verdi:

- Swift core tests;
- Windows preview tests;
- iOS simulator builds.

Il job iOS compila sia la build standard sia quella sperimentale con Xcode 27.

## 3. Genera le IPA

Apri:

```text
Actions → Build distributables → Run workflow
```

Scarica l’artifact:

```text
LyriCar-standard-unsigned-IPA
```

Al suo interno troverai:

```text
LyriCar-standard-unsigned.ipa
LyriCar-standard-unsigned.ipa.sha256
```

Firma e installa l’IPA con il metodo di sideload che utilizzi normalmente.

## 4. Prima apertura senza Spotify

Apri LyriCar e premi:

```text
Prova subito la demo iPhone
```

La demo permette di verificare immediatamente su iPhone:

- cinque righe;
- transizione prospettica;
- barra e tempi;
- play/pausa;
- precedente e successivo;
- layout verticale.

## 5. Collegamento Spotify

Nel Dashboard Spotify Developer crea una app di tipo **Web API** e inserisci:

```text
Redirect URI: lyricar-login://callback
Bundle ID: com.marlius.lyricar
```

Copia il Client ID. Nell’app LyriCar:

1. incolla il Client ID;
2. premi **Salva e collega Spotify**;
3. autorizza l’account nel browser;
4. apri Spotify e avvia un brano.

LyriCar usa Authorization Code con PKCE, quindi non richiede né conserva il Client Secret.

## 6. Build CarPlay sperimentale

L’artifact:

```text
LyriCar-carplay-experimental-unsigned-IPA
```

serve per il test fullscreen futuro. Un normale certificato di sideload non concede automaticamente `com.apple.developer.carplay-maps`; iOS può quindi rifiutare o ignorare la scena CarPlay anche se l’IPA è compilata correttamente.
