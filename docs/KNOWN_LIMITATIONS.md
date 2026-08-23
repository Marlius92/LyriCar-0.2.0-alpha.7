# Limiti noti e condizioni esterne

LyriCar contiene l'implementazione completa prevista dalle milestone M0–M5, ma alcune funzioni dipendono da servizi, permessi e runtime che il repository non può controllare.

## 1. Fullscreen CarPlay

Il renderer fullscreen è implementato in `CarPlaySceneDelegate.swift`, usando una scena `CPTemplateApplicationScene`, un `CPMapTemplate` radice e la `CPWindow` fornita alle app di navigazione.

Non è però una funzione attivabile aggiungendo semplicemente una chiave al file degli entitlement:

- Apple deve concedere l'entitlement `com.apple.developer.carplay-maps` all'account e all'App ID;
- il provisioning profile usato per firmare l'IPA deve contenere lo stesso entitlement;
- Apple destina `CPWindow` al rendering della mappa di un'app di navigazione, non a una schermata lyrics generica;
- il comportamento finale deve essere verificato nel CarPlay Simulator e su un'unità reale.

La build standard usa quindi `Config/LyriCar.entitlements` e non dichiara permessi non concessi. `Config/LyriCar-CarPlay.experimental.entitlements` è presente soltanto per il proof of concept, dopo un'eventuale concessione.

## 2. Live Activity CarPlay

La Live Activity è il percorso supportato e non richiede un entitlement CarPlay dell'app. Il sistema decide però posizione, dimensione, frequenza di aggiornamento e disponibilità nella Dashboard. Non può diventare un'interfaccia fullscreen arbitraria.

La presentazione delle Live Activities nella Dashboard CarPlay è disponibile da iOS 26. Per evitare percorsi condizionali e mantenere il target coerente con questa funzione, LyriCar imposta iOS 26.0 come deployment target minimo.

## 3. Spotify Web API

LyriCar usa Authorization Code con PKCE e gli endpoint Player della Spotify Web API.

Condizioni pratiche:

- in Development Mode il proprietario dell'app Spotify deve avere Premium;
- l'app può essere usata soltanto dagli account ammessi dal dashboard, entro i limiti correnti di Spotify;
- play, pausa, precedente e successivo tramite Player API richiedono Premium e un dispositivo Spotify attivo;
- quote, rate limit, endpoint e politiche possono cambiare;
- l'uso personale non esonera automaticamente dai termini della Spotify Platform.

Le pagine correnti della Spotify Platform includono inoltre una regola che vieta di sincronizzare registrazioni Spotify con contenuti visivi. Una schermata di lyrics temporizzata potrebbe ricadere in tale interpretazione. Il repository costituisce quindi un'implementazione tecnica sperimentale; non afferma che Spotify approvi questo specifico utilizzo.

## 4. Redirect URI iOS

La build standard usa `lyricar-login://callback`; la build sperimentale usa `lyricar-exp-login://callback`. Il valore viene letto dal relativo `Info.plist`, mostrato nell’onboarding e deve corrispondere esattamente a quello registrato nel Dashboard Spotify insieme al Bundle ID del target.

Spotify documenta regole specifiche per gli schemi personalizzati delle app iOS: caratteri minuscoli, prefisso univoco dedicato all’autenticazione e presenza di un percorso dopo `//`. Le due callback di LyriCar rispettano questa struttura. Le regole HTTPS/loopback della pagina Web API generica non sostituiscono le istruzioni iOS del Dashboard.

La Preview Windows usa invece il loopback esplicito `http://127.0.0.1:8765/callback`.

## 5. Background iOS

L'interpolazione del timestamp continua localmente finché il processo può essere eseguito. iOS può sospendere le app in background. Il Drive Mode opzionale usa Core Location a bassa precisione e scarta immediatamente tutti i campioni, ma:

- richiede autorizzazione dell'utente;
- mostra l'indicatore di localizzazione in background;
- non garantisce esecuzione illimitata;
- deve essere usato soltanto quando necessario.

Senza Drive Mode, gli aggiornamenti riprendono quando l'app torna attiva. Una soluzione di produzione più robusta potrebbe richiedere Spotify App Remote, push ActivityKit o altre API consentite dal sistema.

## 6. Lyrics e LRCLIB

LRCLIB può non contenere un brano, restituire una versione diversa o avere timestamp imprecisi. LyriCar include ranking, cache, fallback e offset manuale, ma non può garantire copertura completa. I diritti e le condizioni dei testi restano responsabilità della sorgente e dell'utilizzatore.

## 7. Precisione della timeline del player

Windows Media Control e Spotify Web API non aggiornano necessariamente la posizione alla stessa frequenza del renderer. LyriCar usa quindi un orologio locale riconciliato invece di sostituire direttamente la posizione mostrata a ogni risposta. I piccoli campioni arretrati vengono filtrati, mentre i veri seek vengono applicati.

La modalità Windows compensa inoltre l'età dichiarata dal campione GSMTC tramite `LastUpdatedTime`. Resta possibile che specifiche versioni di Spotify o driver multimediali forniscano metadati temporali anomali; per questo è mantenuto l'offset manuale dei lyrics.

## 8. Stato della verifica

Verificato nell'ambiente di consegna:

- test unitari Swift del core;
- test Python della Preview Windows;
- test specifici del filtro anti-arretramento e dei seek;
- avvio e controllo visivo della Preview sul profilo verticale Renault Clio 9,3";
- mantenimento e avvio del profilo alternativo CarPlay 800×480;
- validità sintattica dei file Swift;
- validità Python, plist, entitlement, privacy manifest e YAML;
- struttura dei workflow GitHub Actions.

Non verificabile in questo ambiente Linux:

- type-check e link completi con SDK iOS/Xcode;
- installazione e firma dell'IPA su iPhone;
- login Spotify reale con un Client ID dell'utente;
- resa nel CarPlay Simulator;
- connessione all'unità CarPlay dell'auto;
- risoluzione e area utile esatte comunicate dall'unità Easy Link durante una connessione reale;
- concessione dell'entitlement navigation.
