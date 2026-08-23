#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] Swift core tests"
swift test

echo "[2/6] Python tests"
python3 -m unittest discover -s WindowsPreview/tests -v

echo "[3/6] Python syntax"
python3 -m compileall -q WindowsPreview

echo "[4/6] Swift syntax"
while IFS= read -r -d '' file; do
  swiftc -frontend -parse "$file" >/dev/null
done < <(find Sources Tests LyriCarApp LyriCarWidgets -name '*.swift' -print0)

echo "[5/6] XML manifests"
python3 - <<'PY'
from pathlib import Path
import plistlib
root = Path('.')
files = [
    root/'LyriCarApp/Resources/Info.plist',
    root/'LyriCarApp/Resources/Info-CarPlay.plist',
    root/'LyriCarWidgets/Info.plist',
    root/'LyriCarApp/Resources/PrivacyInfo.xcprivacy',
    root/'Config/LyriCar.entitlements',
    root/'Config/LyriCar-CarPlay.experimental.entitlements',
    root/'Config/LyriCarWidgets.entitlements',
]
for path in files:
    with path.open('rb') as handle:
        plistlib.load(handle)
    print(f'  OK {path}')
PY

echo "[6/6] Repository invariants"
python3 - <<'PY'
from pathlib import Path
import json
root = Path('.')
version = (root/'VERSION').read_text().strip()
if version != '0.2.0-alpha.7':
    raise SystemExit(f'Versione inattesa: {version}')
required = [
    'project.yml', 'Package.swift', 'README.md', 'BUILD_STATUS.md',
    'START_HERE_IPHONE_WINDOWS.md', 'CORREZIONE_TRANSIZIONE.txt',
    'docs/ARCHITECTURE.md', 'docs/MILESTONES.md', 'docs/CARPLAY.md',
    'docs/KNOWN_LIMITATIONS.md', 'docs/images/preview-800x480.png',
    'docs/images/preview-renault-clio-9.3.png',
    'LyriCarApp/App/LyriCarApp.swift',
    'LyriCarApp/CarPlay/CarPlaySceneDelegate.swift',
    'LyriCarApp/Spotify/SpotifyConfiguration.swift',
    'LyriCarApp/Demo/LyriCarDemo.swift',
    'Sources/LyriCarCore/Sync/PlaybackClock.swift',
    'LyriCarWidgets/LyriCarLiveActivity.swift',
    'WindowsPreview/lyricar_preview.py',
    'WindowsPreview/pillow_lyrics_renderer.py',
    'WindowsPreview/requirements-preview.txt',
    'WindowsPreview/tests/test_pillow_renderer.py',
    'WindowsPreview/run_preview.bat',
    'WindowsPreview/run_preview_generic.bat',
    'WindowsPreview/run_spotify_locale.bat',
    'WindowsPreview/windows_media_client.py',
    'WindowsPreview/requirements-windows-local.txt',
]
missing = [p for p in required if not (root/p).exists()]
if missing:
    raise SystemExit(f'Mancano file obbligatori: {missing}')
if (root/'Config/Secrets.local.xcconfig').exists():
    raise SystemExit('Config/Secrets.local.xcconfig non deve essere incluso nel pacchetto')
project_text = (root/'project.yml').read_text()
for marker in ('iOS: "26.0"', 'LyriCarExperimental:', 'LyriCarWidgetsExperimental:'):
    if marker not in project_text:
        raise SystemExit(f'Configurazione progetto incompleta: manca {marker}')
standard_target = project_text.split('  LyriCar:', 1)[1].split('  LyriCarExperimental:', 1)[0]
if '- CarPlay' not in standard_target:
    raise SystemExit('Il target standard deve escludere la cartella CarPlay')
widget_text = (root/'LyriCarWidgets/LyriCarLiveActivity.swift').read_text()
if '.supplementalActivityFamilies([.small])' not in widget_text:
    raise SystemExit('Supporto ActivityFamily.small mancante')
config_text = (root/'LyriCarApp/Spotify/SpotifyConfiguration.swift').read_text()
for marker in ('lyricar-login://callback', 'SpotifyConfigurationStore', 'func save(clientID'):
    if marker not in config_text:
        raise SystemExit(f'Configurazione Spotify runtime incompleta: manca {marker}')
app_model = (root/'LyriCarApp/App/AppModel.swift').read_text()
for marker in ('case demo', 'func startDemo()', 'LyriCarDemo'):
    if marker not in app_model:
        raise SystemExit(f'Modalità demo iPhone incompleta: manca {marker}')
standard_info = (root/'LyriCarApp/Resources/Info.plist').read_text()
experimental_info = (root/'LyriCarApp/Resources/Info-CarPlay.plist').read_text()
if 'CPTemplateApplicationSceneSessionRoleApplication' in standard_info:
    raise SystemExit('La build standard non deve dichiarare la scena CarPlay fullscreen')
if 'CPTemplateApplicationSceneSessionRoleApplication' not in experimental_info:
    raise SystemExit('La build sperimentale deve dichiarare la scena CarPlay')
if 'lyricar-login://callback' not in standard_info:
    raise SystemExit('Redirect URI della build standard non coerente')
if 'lyricar-exp-login://callback' not in experimental_info:
    raise SystemExit('Redirect URI della build sperimentale non coerente')
onboarding = (root/'LyriCarApp/Features/Onboarding/SpotifyOnboardingView.swift').read_text()
for marker in ('Prova subito la demo iPhone', 'configureAndConnectSpotify', 'spotifyConfiguration.redirectURI'):
    if marker not in onboarding:
        raise SystemExit(f'Onboarding iPhone incompleto: manca {marker}')
preview_text = (root/'WindowsPreview/lyricar_preview.py').read_text()
if 'renault_clio_9_3' not in preview_text or '600, 800' not in preview_text:
    raise SystemExit('Profilo Renault Clio 9,3 pollici mancante dalla Preview Windows')
if 'windows_media' not in preview_text or 'Spotify locale — senza Client ID' not in preview_text:
    raise SystemExit('Modalità Spotify locale Windows mancante')
if '_schedule_next_frame' not in preview_text or 'PillowLyricsRenderer' not in preview_text:
    raise SystemExit('Renderer Pillow sub-pixel a 60 FPS mancante')
renderer_text = (root/'WindowsPreview/pillow_lyrics_renderer.py').read_text()
for marker in ('quarter_units', 'Image.new("RGB"', 'prepare_transition', 'transition_curve'):
    if marker not in renderer_text:
        raise SystemExit(f'Compositore sub-pixel incompleto: manca {marker}')
core_text = (root/'WindowsPreview/lyricar_core.py').read_text()
if 'class PlaybackReconciler' not in core_text:
    raise SystemExit('PlaybackReconciler anti-arretramento mancante dalla Preview Windows')
swift_clock = (root/'Sources/LyriCarCore/Sync/PlaybackClock.swift').read_text()
if 'public struct PlaybackClock' not in swift_clock:
    raise SystemExit('PlaybackClock mancante dal core Swift')
swift_renderer = (root/'LyriCarApp/Features/Lyrics/LyriCarLyricsView.swift').read_text()
if 'minimumInterval: 1.0 / 60.0' not in swift_renderer or 'transitionCurve(frame.transitionProgress)' not in swift_renderer:
    raise SystemExit('Renderer SwiftUI fluido a 60 Hz con curva continua mancante')
json.loads((root/'LyriCarApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
json.loads((root/'LyriCarApp/Resources/Assets.xcassets/AccentColor.colorset/Contents.json').read_text())
print('  struttura, build separate, demo iPhone e asset validi')
try:
    import yaml
except ImportError:
    print('  PyYAML non installato: controllo YAML saltato')
else:
    for path in ('project.yml', '.github/workflows/ci.yml', '.github/workflows/build-distributables.yml'):
        yaml.safe_load((root/path).read_text())
        print(f'  YAML valido: {path}')
PY

echo "Validazione LyriCar completata."
