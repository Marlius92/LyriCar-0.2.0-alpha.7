# Changelog

## 0.2.0-alpha.7 — 2026-08-23

Prima revisione destinata alla compilazione e alla prova su iPhone.

### Aggiunto

- modalità demo iPhone completa, con testo originale, timeline simulata e controlli locali;
- Client ID Spotify inseribile direttamente nell’onboarding;
- memorizzazione locale del Client ID e configurazione runtime senza nuova compilazione;
- Redirect URI mostrata e copiabile dall’app;
- build iOS standard e CarPlay sperimentale separate;
- bundle ID, URL scheme e callback distinti per i due target;
- onboarding con accesso alla demo, dashboard Spotify e collegamento PKCE;
- polling adattivo tra app attiva, CarPlay e Drive Mode;
- riavvio sicuro del polling dopo errori o riconnessioni;
- esclusione fisica dei sorgenti CarPlay dal target standard;
- guida completa per produrre la prima IPA partendo da Windows;
- workflow aggiornati ai runner Xcode 27 e alle revisioni correnti delle GitHub Actions.

### Conservato

- renderer Windows sub-pixel 0.1.5-alpha.6 approvato dall’utente;
- clock anti-arretramento;
- motore LRC/LRCLIB, cache, offset e controlli Spotify;
- Live Activity come percorso CarPlay supportato dal sistema.

### Da verificare

- compilazione/linking iOS nel primo workflow GitHub Actions;
- firma e installazione IPA su iPhone;
- login Spotify reale;
- resa della Live Activity e del proof of concept CarPlay.

## 0.1.5-alpha.6 — 2026-08-23

Correzione strutturale degli scatti residui nelle transizioni lunghe.

### Aggiunto

- compositore lyrics Pillow separato da Tk, con glifi prerenderizzati ad alta risoluzione;
- scala del testo a quarti di pixel invece dei precedenti salti di 2 punti;
- preparazione preventiva delle maschere necessarie alla transizione successiva;
- riuso di una sola immagine Tk durante l'animazione, senza ricrearla a ogni frame;
- pannello RGB ottimizzato per evitare il costo elevato dell'upload RGBA di Tk;
- curva di transizione ammorbidita, composta per il 20% da moto lineare e per l'80% da `smoothstep`;
- installazione automatica di Pillow dai launcher Windows;
- test automatici per layout stabile, compositing RGB, pre-riscaldamento e risoluzione sub-pixel.

### Corretto

- la crescita e la riduzione del testo non rimangono più ferme per diversi frame sulla stessa dimensione;
- aumentando la durata fino a 1,2 secondi non vengono più esposti i gradini della vecchia quantizzazione;
- il renderer non chiede più a Tk di rasterizzare continuamente il testo a dimensioni differenti;
- il trasferimento dell'immagine lyrics al Canvas non usa più un buffer RGBA molto più lento su Windows/Tk;
- partenza e arresto delle transizioni lunghe non sembrano più bloccati agli estremi della curva.

### Verifica sul preset 600×800

Benchmark sintetico con transizione impostata a 1,2 secondi in Linux/Xvfb:

- dimensioni effettive della riga principale: da **10** a **61**;
- permanenza consecutiva massima sulla stessa dimensione: da **11** a **3 frame**;
- intervallo medio tra frame: **16,85 ms**;
- 95º percentile dell'intervallo: **17,45 ms**;
- tempo medio di disegno: **1,71 ms**;
- 95º percentile del disegno: **5,71 ms**.

La prova Windows reale resta necessaria perché rasterizzazione, scheduler e driver grafici differiscono dall'ambiente di sviluppo.

## 0.1.4-alpha.5 — 2026-08-23

Correzione dei micro-scatti durante il passaggio da una riga all'altra.

### Aggiunto

- scheduler grafico a scadenza assoluta da 60 FPS: il tempo impiegato dal disegno non si somma più al timer;
- cache preventiva dei font usati dal preset Renault da 9,3 pollici;
- riuso di sei elementi di testo Canvas, senza crearli o eliminarli al cambio riga;
- cache delle proprietà e delle coordinate già applicate agli elementi grafici;
- ridimensionamento del testo a passi di 2 punti, mentre posizione e dissolvenza restano aggiornate a ogni fotogramma;
- curva `smoothstep` per partenza e arresto progressivi;
- migrazione automatica della durata predefinita da 0,45 a 0,55 secondi, lasciando invariati i valori personalizzati;
- test automatici per easing e quantizzazione del font.

### Corretto

- i micro-scatti più evidenti quando la riga centrale diventava piccola e la successiva diventava grande;
- i picchi dovuti alla prima rasterizzazione di ogni nuova dimensione del font;
- l'allocazione di un nuovo oggetto Canvas esattamente al confine tra due righe;
- la perdita di frequenza prodotta dal precedente ciclo `after(16)`;
- le riconfigurazioni ripetute di titolo, timer, controlli e proprietà grafiche già identiche.

### Prestazioni misurate sul profilo 600×800

Benchmark sintetico di un secondo con Tk 8.6 in Linux/Xvfb, utile per confrontare le due revisioni ma non sostitutivo della verifica sul PC Windows reale:

- fotogrammi completati: da 49 a 61;
- intervallo medio tra i fotogrammi: da 20,85 ms a 16,66 ms;
- 95º percentile: da 31,07 ms a 17,42 ms;
- intervalli superiori a 20 ms: da 18 a 0.

## 0.1.3-alpha.4 — 2026-08-23

Correzione della continuità temporale tra Spotify, barra di avanzamento e lyrics.

### Aggiunto

- `PlaybackReconciler` nella Preview Windows, con orologio locale continuo e testabile;
- `PlaybackClock` nel core Swift, condiviso dall'app iPhone e dai renderer;
- compensazione dell'età del campione GSMTC tramite `LastUpdatedTime`;
- riconoscimento separato di avanzamento normale, campione obsoleto, pausa e seek reale;
- protezione dagli eventi multimediali ricevuti fuori ordine;
- test automatici per campioni quantizzati, pausa, seek indietro e seek da fermo.

### Corretto

- la barra non avanza più per poi tornare indietro a ogni aggiornamento di Windows Media Control;
- il testo non ripete più la stessa transizione a causa di piccoli arretramenti del timestamp;
- i campioni Spotify leggermente arretrati non sostituiscono più l'interpolazione già visualizzata;
- un vero salto nella canzone continua a riposizionare immediatamente barra e lyrics;
- la posizione alla prima lettura locale tiene conto del momento in cui Windows ha aggiornato la timeline.

## 0.1.2-alpha.3 — 2026-08-23

Nuova integrazione Spotify locale per Windows e correzione del percorso Web API.

### Aggiunto

- modalità `Spotify locale — senza Client ID` tramite Windows Media Control/GSMTC;
- lettura di titolo, artista, durata, posizione e stato play/pausa dalla sessione Spotify;
- controlli locale play, pausa, precedente e successivo;
- avvio guidato `run_spotify_locale.bat` con installazione automatica della dipendenza WinRT;
- launcher radice `AVVIA_CON_SPOTIFY.bat` nel pacchetto Windows;
- comando `Spotify → Apri Spotify`;
- comando `Spotify → Apri Dashboard sviluppatori`;
- pulsanti guidati nelle impostazioni per Dashboard, Spotify e `Salva e collega`;
- apertura automatica dell'app Spotify dopo l'autorizzazione;
- fallback automatico al Web Player se l'app desktop non è installata;
- fallback robusto per l'apertura del browser OAuth;
- salvataggio locale dell'ultimo URL di autorizzazione quando Windows non apre il browser;
- messaggi più chiari quando Spotify è collegata ma non esiste ancora un brano attivo.

### Corretto

- token appartenenti a un Client ID precedente non vengono più riutilizzati con un'altra app Spotify;
- la Preview non lascia più intendere che il Client ID debba avviare direttamente il player musicale.

## 0.1.1-alpha.2 — 2026-08-23

Aggiornamento del renderer per il display target Renault Clio Easy Link da 9,3".

### Aggiunto

- profilo Windows predefinito `Renault Clio — Easy Link 9,3"` in formato verticale;
- profilo alternativo CarPlay generico 800×480 orizzontale;
- cambio profilo da `Visualizza → Profilo display`;
- avvio diretto del preset Renault tramite `run_preview.bat`;
- layout adattivo specifico per superfici verticali: spaziatura lyrics, progress bar e controlli;
- screenshot di riferimento verticale 600×800.

### Corretto

- preview iniziale non più vincolata al solo formato 1000×600 orizzontale;
- stato della preview riposizionato per non sovrapporsi a titolo e artista sul formato verticale.

## 0.1.0-alpha.1 — 2026-08-23

Prima implementazione completa M0–M5.

### Aggiunto

- renderer LyriCar a cinque righe con scala, dissolvenza, profondità e transizione continua;
- titolo, artista, barra di avanzamento, tempo trascorso/restante e controlli essenziali;
- parser LRC, offset, ricerca LRCLIB, ranking e cache positiva/negativa;
- OAuth Spotify PKCE, Keychain, refresh token, Now Playing e controlli Player API;
- app iPhone SwiftUI, impostazioni e Drive Mode opzionale;
- Live Activity, Dynamic Island e presentazione compatta per CarPlay;
- scena CarPlay navigation/`CPWindow` sperimentale;
- Preview Windows con modalità demo, file LRC e Spotify reale;
- test Swift/Python, workflow CI, build EXE e IPA non firmata;
- documentazione completa, privacy manifest e asset originali.
