# LyriCar 0.3.3-alpha.17 — CarPlay Live Activity Lyrics

Questa build sposta il test CarPlay principale dalla timeline dei widget alla **Live Activity**.

## Obiettivo del test

Verificare se CarPlay aggiorna in modo sufficientemente rapido la riga corrente dei lyrics mentre Spotify originale continua a essere il player.

## Modifiche

- Live Activity preparata mentre LyriCar è ancora in primo piano, così può continuare a ricevere aggiornamenti dopo il passaggio a Spotify.
- Layout CarPlay `ActivityFamily.small` dedicato ai lyrics.
- Cinque righe: `-2`, `-1`, corrente, `+1`, `+2`.
- Riga corrente più grande e luminosa; contesto progressivamente attenuato.
- Transizione in dissolvenza tra una riga e la successiva.
- Tick locale a 250 ms quando CarPlay è collegato e il brano è in riproduzione, ma ActivityKit viene aggiornato solo quando cambia la finestra dei lyrics/stato o al bucket di correzione della posizione.
- Spotify originale resta completamente separato e non viene modificato.

## Procedura di prova

1. Installa la build standard.
2. Apri LyriCar e lascia attiva **Live Activity**.
3. Per un controllo rapido, avvia prima la modalità Demo e verifica sul Lock Screen che la riga corrente cambi.
4. Torna a LyriCar, collega Spotify e poi apri Spotify originale.
5. Avvia un brano con lyrics sincronizzati.
6. Collega CarPlay.
7. Apri la Dashboard/Home di CarPlay e verifica la Live Activity LyriCar.
8. Controlla se la riga corrente avanza a ogni cambio di timestamp e annota eventuali ritardi o blocchi.

## Limite da verificare sul dispositivo reale

ActivityKit e CarPlay restano controllati da iOS. Questa build implementa gli aggiornamenti richiesti, ma solo il test sull'head unit reale può stabilire se iOS li presenta senza throttling percepibile.
