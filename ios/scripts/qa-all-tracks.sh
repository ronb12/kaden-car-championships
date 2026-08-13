#!/usr/bin/env bash
# Screenshot each catalog track in full environment (DEBUG -qaTrackIndex=N).
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
IOS="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$IOS/test-screenshots/qa-tracks-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"
TRACK_COUNT=21

mkdir -p "$OUT"
echo "Building…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)
xcrun simctl install "$UDID" "$APP"

for ((i = 0; i < TRACK_COUNT; i++)); do
  name=$(printf "%02d" "$i")
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.35
  xcrun simctl launch "$UDID" "$BUNDLE" "-qaTrackIndex=$i" -qaRace >/dev/null
  sleep "${DRIVE_SEC:-14}"
  xcrun simctl io "$UDID" screenshot "$OUT/track-${name}.png"
  echo "  track $i → track-${name}.png"
done

echo "Track environment shots: $OUT"
