#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${1:-LyriCar}"
PRODUCT_NAME="${2:-LyriCar}"
ARTIFACT_NAME="${3:-LyriCar-unsigned}"
SAFE_SCHEME="$(printf '%s' "$SCHEME" | tr -c 'A-Za-z0-9._-' '_')"
DERIVED_DATA="build/DerivedData-${SAFE_SCHEME}"
STAGING="build/ipa-${SAFE_SCHEME}"
ARTIFACTS="build/artifacts"

bash "$ROOT/scripts/generate_project.sh"
rm -rf "$DERIVED_DATA" "$STAGING"
mkdir -p "$STAGING/Payload" "$ARTIFACTS"

xcodebuild \
  -project LyriCar.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/${PRODUCT_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle non trovato: $APP_PATH" >&2
  find "$DERIVED_DATA/Build/Products/Release-iphoneos" -maxdepth 1 -type d -name '*.app' -print >&2 || true
  exit 1
fi

# The AppIcon asset catalog must have been compiled by actool into Assets.car.
# Refuse to publish a broken IPA if the asset catalog was omitted from the target.
if [[ ! -f "$APP_PATH/Assets.car" ]]; then
  echo "ERRORE: Assets.car non presente in ${PRODUCT_NAME}.app. L'asset catalog/AppIcon non e stato compilato." >&2
  echo "Contenuto del bundle:" >&2
  find "$APP_PATH" -maxdepth 2 -type f -print | sort >&2 || true
  exit 1
fi

echo "Verifica AppIcon: Assets.car presente ($(du -h "$APP_PATH/Assets.car" | awk '{print $1}'))."
if /usr/libexec/PlistBuddy -c 'Print :CFBundleIcons' "$APP_PATH/Info.plist" >/dev/null 2>&1; then
  echo "Verifica AppIcon: CFBundleIcons presente in Info.plist."
else
  echo "Avviso: CFBundleIcons non esplicito; iOS moderno puo ricavare l'icona dall'asset catalog compilato."
fi

ditto "$APP_PATH" "$STAGING/Payload/${PRODUCT_NAME}.app"
(
  cd "$STAGING"
  /usr/bin/zip -qry "$ROOT/$ARTIFACTS/${ARTIFACT_NAME}.ipa" Payload
)

shasum -a 256 "$ARTIFACTS/${ARTIFACT_NAME}.ipa" > "$ARTIFACTS/${ARTIFACT_NAME}.ipa.sha256"
echo "Creato: $ARTIFACTS/${ARTIFACT_NAME}.ipa"
