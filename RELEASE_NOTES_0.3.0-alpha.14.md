# LyriCar 0.3.0-alpha.14 — Multi-Widget CarPlay Lab

Questa release aggiunge tre widget `systemSmall` coordinati e mantiene la Live Activity esistente.

## Widget disponibili

- **LyriCar · Prima** — due righe precedenti e contesto della riga corrente.
- **LyriCar · Corrente** — riga corrente grande, titolo/artista e progressione brano.
- **LyriCar · Dopo** — due righe successive e tempo restante.

I tre widget condividono lo stesso snapshot di riproduzione tramite App Group. La build di test usa un App Group già autorizzato dal provisioning Distribution Signulous fornito per il dispositivo di prova.

## Obiettivo CarPlay

CarPlay usa esclusivamente la famiglia `systemSmall` e decide autonomamente quanti stack/slot mostrare. Se l'head unit Renault offre più slot, i tre widget possono essere aggiunti separatamente per formare una superficie lyrics distribuita. Se l'head unit espone un solo stack, i tre widget resteranno selezionabili ma verranno mostrati uno alla volta nello stack.

## Limiti intenzionali

- Nessun controllo play/pausa/skip nel widget: si usano i controlli dell'auto.
- Il karaoke a 60 Hz resta nell'app principale. WidgetKit non garantisce aggiornamenti frame-by-frame; il widget corrente mostra la riga sincronizzata e la progressione del brano gestita dal sistema.
- L'ordinamento e il numero di widget visibili contemporaneamente dipendono da CarPlay e dall'head unit.
