# Third-party services and SDKs

LyriCar non incorpora codice di Spotify, LRCLIB o Apple.

- Spotify Web API e Spotify Accounts vengono usati tramite richieste HTTPS e OAuth PKCE.
- LRCLIB viene interrogato tramite la sua API pubblica per ottenere lyrics sincronizzati.
- ActivityKit, WidgetKit, CarPlay, Core Location, AuthenticationServices e Keychain sono framework Apple.

I nomi e marchi appartengono ai rispettivi proprietari. Il codice del repository è originale e non include lyrics commerciali; il file demo contiene testo originale creato per il progetto.
## Dipendenze della Preview Windows

- **Pillow** viene usato per il prerendering e il compositing sub-pixel dei lyrics ed è distribuito con licenza HPND.
- **PyWinRT / winrt-Windows.Media.Control** espone a Python la sessione multimediale di Windows usata per leggere Spotify locale.
- **PyInstaller** viene usato soltanto nel processo di build dell'EXE Windows.

