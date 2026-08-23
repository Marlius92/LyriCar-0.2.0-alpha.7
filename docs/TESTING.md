# Build e test

## Validazione completa locale

```bash
./scripts/validate.sh
```

Esegue:

- `swift test` sul core;
- test `unittest` della Preview, inclusi campioni GSMTC quantizzati e seek;
- compilazione sintattica Python;
- parse di tutti i file Swift;
- verifica XML di plist, entitlement e privacy manifest;
- verifica YAML quando PyYAML è disponibile.

## Preview Windows

```powershell
cd WindowsPreview
py -m unittest discover -s tests -v
py lyricar_preview.py --profile renault_clio_9_3
```

Oppure fai doppio clic su `run_preview.bat`. Per il formato CarPlay generico orizzontale usa `run_preview_generic.bat`.

Per verificare il percorso Spotify locale senza Client ID:

```powershell
run_spotify_locale.bat
```

La barra e le lyrics devono avanzare in modo continuo anche quando Windows restituisce lo stesso timestamp per più polling consecutivi. Un seek evidente in Spotify deve invece riposizionare immediatamente entrambi.

Build EXE:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
```

## App iOS su Mac

Prerequisiti: Xcode 26 o successivo e XcodeGen.

```bash
./scripts/generate_project.sh
xcodebuild \
  -project LyriCar.xcodeproj \
  -scheme LyriCar \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## IPA non firmata

```bash
./scripts/build_unsigned_ipa.sh
```

L'IPA viene creata in `build/artifacts/LyriCar-unsigned.ipa`. Deve poi essere firmata con il proprio account/metodo di sideload.

## GitHub Actions

- `CI`: test Swift/Python e build iOS Simulator.
- `Build distributables`: crea EXE Windows e IPA non firmata come artifact scaricabili.
