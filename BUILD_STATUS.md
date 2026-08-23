# LyriCar — stato della build

Versione sorgente: **0.2.0-alpha.7**  
Milestone incluse: **M0, M1, M2, M3, M4, M5**  
Display fisico target: **Renault Clio Easy Link 9,3" verticale**  
Target iOS: **26.0+**

## Base approvata

La Preview Windows conserva integralmente il renderer sub-pixel approvato nella revisione `0.1.5-alpha.6`:

- cinque righe prospettiche;
- scala a quarti di pixel;
- compositing Pillow RGB;
- transizione continua anche con durata elevata;
- orologio Spotify anti-arretramento;
- barra, timer e testo controllati dallo stesso clock.

Questa parte non viene modificata funzionalmente dalla revisione iPhone.

## Revisione iPhone First Run

La versione `0.2.0-alpha.7` aggiunge:

- modalità demo nativa iPhone, senza Spotify e senza audio;
- Client ID Spotify inseribile e sostituibile dall’app;
- OAuth Authorization Code con PKCE;
- Redirect URI letta dal bundle e mostrata nell’onboarding;
- build standard priva di entitlement CarPlay non concessi;
- build `LyriCarExperimental` separata per il proof of concept `CPWindow`;
- callback diverse per build standard e sperimentale;
- polling adattivo, con interpolazione locale continua;
- GitHub Actions su runner Xcode 27;
- IPA standard e sperimentale prodotte come artifact distinti.

## Verifiche locali completate

- 17/17 test Swift del core superati.
- 20/20 test Python della Preview superati.
- Tutti i moduli Python superano `compileall`.
- Tutti i sorgenti Swift superano il parser sintattico.
- Plist, entitlement, privacy manifest e YAML validi.
- Preview Renault 9,3" e profilo CarPlay generico mantenuti.
- Build standard e sperimentale isolate in target e scheme differenti.

## Verifiche ancora esterne

L’ambiente locale non include Xcode né gli SDK iOS. Restano quindi da eseguire tramite GitHub Actions e dispositivo:

1. type-check e linking completi con Xcode 27;
2. generazione dell’IPA standard non firmata;
3. firma e installazione sull’iPhone;
4. prova della modalità demo iPhone;
5. login Spotify reale con il Client ID dell’utente;
6. Live Activity su iPhone/CarPlay;
7. eventuale test della build sperimentale soltanto con entitlement compatibile.

## Stato CarPlay

- **Live Activity:** implementata nella build standard; dimensione e posizione sono controllate dal sistema.
- **Fullscreen `CPWindow`:** sorgente implementato nella build sperimentale.
- **Entitlement navigation Apple:** non incluso nella build standard e non verificato.
- **Display Renault:** nessuna risoluzione nativa viene presunta; il layout usa la superficie runtime.
