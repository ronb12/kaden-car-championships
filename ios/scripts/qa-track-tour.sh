#!/usr/bin/env bash
# Test-drive every catalog track with QA autopilot; capture scenery screenshots per lap.
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
IOS="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$IOS/test-screenshots/qa-tour-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"
TRACK_COUNT="${TRACK_COUNT:-21}"
DRIVE_SEC="${DRIVE_SEC:-18}"

mkdir -p "$OUT"
echo "Building…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)
xcrun simctl install "$UDID" "$APP"

for ((i = 0; i < TRACK_COUNT; i++)); do
  name=$(printf "%02d" "$i")
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.4
  xcrun simctl launch "$UDID" "$BUNDLE" "-qaTrackIndex=$i" -qaRace -qaDrive >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/track-${name}-start.png"
  sleep "$((DRIVE_SEC / 2))"
  xcrun simctl io "$UDID" screenshot "$OUT/track-${name}-mid.png"
  sleep "$((DRIVE_SEC / 2))"
  xcrun simctl io "$UDID" screenshot "$OUT/track-${name}-lap.png"
  echo "  track $i → track-${name}-{start,mid,lap}.png"
done

echo "Track tour screenshots: $OUT"
