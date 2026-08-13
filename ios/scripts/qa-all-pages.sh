#!/usr/bin/env bash
# Fresh simulator + screenshot every major game screen.
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
IOS="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$IOS/test-screenshots/qa-pages-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"

mkdir -p "$OUT"
tap() { cliclick "c:$1,$2"; sleep "${3:-0.75}"; }
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png"; echo "  → $1.png"; }
launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.4
  if [[ $# -eq 0 ]]; then
    xcrun simctl launch "$UDID" "$BUNDLE"
  else
    xcrun simctl launch "$UDID" "$BUNDLE" "$@"
  fi
  sleep 2.2
}
focus_sim() {
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  sleep 0.35
}

echo "Building Debug app…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)

echo "Refreshing simulator $UDID…"
xcrun simctl shutdown "$UDID" 2>/dev/null || true
sleep 1
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b 2>/dev/null || sleep 8
open -a Simulator >/dev/null 2>&1 || true
sleep 2

xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
focus_sim

echo "=== Core menus ==="
launch -qaTapTest
shot "01-main-menu"

launch -qaTapTest -qaSettings
shot "02-settings-sheet"

launch -qaTapTest -qaPrivacy
shot "03-privacy-sheet"

launch -qaTapTest -qaTerms
shot "04-terms-sheet"

launch -qaTapTest -qaModes
shot "05-arcade-modes"

echo "=== Garage flows ==="
launch -qaTapTest -qaGarage
shot "06-garage-quick-race"

launch -qaTapTest -qaGarageChamp
shot "07-garage-championship"

launch -qaTapTest -qaGarageCareer
shot "08-garage-career"

launch -qaTapTest -qaGarageDaily
shot "09-garage-daily-challenge"

launch -qaTapTest -qaGaragePolice
shot "10-garage-police-chase"

launch -qaTapTest -qaGarageTimeTrial
shot "11-garage-time-trial"

launch -qaTapTest -qaGarageEndless
shot "12-garage-endless"

launch -qaTapTest -qaGarageGhost
shot "13-garage-ghost-duel"

echo "=== Race flow ==="
launch -qaTapTest -qaTrack
shot "14-track-select"

launch -qaTapTest -qaRace
sleep 4
shot "15-in-race"

launch -qaTapTest -qaPaused
sleep 3
shot "16-race-paused"

launch -qaTapTest -qaPolice
sleep 4
shot "17-police-chase-race"

launch -qaTapTest -qaEndless
sleep 4
shot "18-endless-race"

echo "=== Results ==="
launch -qaTapTest -qaFinished
shot "19-race-finished"

launch -qaTapTest -qaChampComplete
shot "20-championship-complete"

echo ""
echo "All page screenshots: $OUT"
echo "Tap QA (gear, footer links, pause, Game Center): bash ios/scripts/qa-menu-taps.sh"
