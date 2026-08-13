#!/usr/bin/env bash
# Automated Simulator QA — in-race via -qaRace, then menu flow taps.
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$ROOT/ios"
OUT="$IOS/test-screenshots/qa-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"

mkdir -p "$OUT"
tap() { cliclick "c:$1,$2"; sleep "${3:-0.6}"; }
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png"; echo "  → $1.png"; }

echo "Building…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)

echo "Installing & launching (-qaRace)…"
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -qaTapTest -qaRace
sleep 3
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true

shot "01-race-start"
sleep 5
shot "02-race-driving"
sleep 10
shot "03-race-corner"
sleep 10
shot "04-race-lap-progress"

echo "Menu flow (Quick Race → track → race)…"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
sleep 0.5
xcrun simctl launch "$UDID" "$BUNDLE"
sleep 2

shot "04-main-menu"
tap 250 478 1.2
shot "05-garage"
tap 250 900 1.5
shot "06-track-select"
tap 250 955 1.2
sleep 5
shot "07-race-menu-flow"

echo "QA screenshots: $OUT"
