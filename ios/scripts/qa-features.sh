#!/usr/bin/env bash
# Full feature QA — debug launch routes + menu navigation screenshots.
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$ROOT/ios"
OUT="$IOS/test-screenshots/qa-features-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"

mkdir -p "$OUT"
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png"; echo "  → $1.png"; }
tap() { cliclick "c:$1,$2"; sleep "${3:-0.7}"; }
launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.5
  xcrun simctl launch "$UDID" "$BUNDLE" "$@"
  sleep 2
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
}

echo "Building…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)
xcrun simctl install "$UDID" "$APP"

echo "=== In-race modes (launch args) ==="
for mode in qaRace qaPolice qaEndless qaDaily qaChamp qaCareer; do
  launch "-$mode"
  sleep 5
  shot "race-$mode-5s"
  sleep 10
  shot "race-$mode-15s"
done

echo "=== Menu flows ==="
launch
shot "menu"
tap 250 478 1.2
shot "garage-quick"
tap 250 900 1.3
shot "track-select"
tap 250 955 1.2
sleep 6
shot "race-menu-flow"

launch "-qaModes"
shot "arcade-modes"
tap 250 420 1.2
shot "time-trial-garage"

launch
tap 250 72 1.5
shot "settings-sheet"

echo "Screenshots: $OUT"
