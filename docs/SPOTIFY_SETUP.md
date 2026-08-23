# Configurazione Spotify

## Windows

Per la Preview Windows usa preferibilmente:

```text
WindowsPreview\run_spotify_locale.bat
```

Questa modalità legge Spotify tramite Windows Media Control e non richiede un Client ID.

## iPhone — build standard

### 1. Crea una app Spotify Developer

Nel Dashboard Spotify Developer crea una app e seleziona **Web API**.

Registra esattamente:

```text
Redirect URI: lyricar-login://callback
Bundle ID: com.marlius.lyricar
```

La Redirect URI deve coincidere carattere per carattere. LyriCar la mostra anche nell’onboarding e permette di copiarla.

### 2. Copia il Client ID

Copia soltanto il **Client ID**, non il Client Secret. LyriCar usa Authorization Code con PKCE e non incorpora un segreto statico.

### 3. Inserisci il Client ID nell’app

Alla prima apertura:

1. incolla il Client ID;
2. premi **Salva e collega Spotify**;
3. autorizza l’account nella sessione di accesso;
4. apri Spotify e avvia un brano.

Il token viene conservato nel Keychain. Il Client ID viene conservato localmente e può essere rimosso dall’app senza ricompilare l’IPA.

## Build CarPlay sperimentale

La build sperimentale è un’app distinta e usa:

```text
Redirect URI: lyricar-exp-login://callback
Bundle ID: com.marlius.lyricar.experimental
```

Questa configurazione serve soltanto dopo aver superato la prova della build standard. Il semplice sideload non concede l’entitlement CarPlay navigation.

## Development Mode

Le app personali nuove operano normalmente in Development Mode. Dal febbraio 2026 il proprietario deve avere Spotify Premium; ogni nuovo Client ID può autorizzare fino a cinque utenti. Per la prima prova di LyriCar basta usare l’account proprietario dell’app.

## Scopes richiesti

```text
user-read-currently-playing
user-read-playback-state
user-modify-playback-state
```

Servono esclusivamente per leggere il brano corrente e inviare precedente, play/pausa e successivo.
