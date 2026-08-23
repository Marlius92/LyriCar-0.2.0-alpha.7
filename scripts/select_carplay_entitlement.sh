#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-status}"
case "$MODE" in
  standard)
    echo "Schema standard: LyriCar"
    echo "Entitlement: Config/LyriCar.entitlements"
    echo "Build: ./scripts/build_unsigned_ipa.sh LyriCar LyriCar LyriCar-standard-unsigned"
    ;;
  experimental)
    echo "Schema sperimentale: LyriCarExperimental"
    echo "Entitlement: Config/LyriCar-CarPlay.experimental.entitlements"
    echo "Build: ./scripts/build_unsigned_ipa.sh LyriCarExperimental LyriCarExperimental LyriCar-carplay-experimental-unsigned"
    echo "Nota: il fullscreen richiede un provisioning profile a cui Apple abbia concesso CarPlay navigation."
    ;;
  status)
    echo "LyriCar mantiene due target separati; non modifica più project.yml."
    echo "- LyriCar: standard, Live Activity e nessun entitlement CarPlay non concesso"
    echo "- LyriCarExperimental: scena CPWindow e entitlement navigation sperimentale"
    ;;
  *)
    echo "Uso: $0 [standard|experimental|status]" >&2
    exit 2
    ;;
esac
