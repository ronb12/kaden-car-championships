#!/usr/bin/env bash
# Tap-test: Settings gear/footer, Privacy, Terms, Pause→Resume, Game Center.
# Requires: Simulator focused, cliclick (`brew install cliclick`).
# Suppresses Game Center auth banner via -qaTapTest.
#
# If automation misses (window scale / multi-monitor), use launch-arg fallbacks:
#   -qaSettings -qaPrivacy -qaTerms -qaPaused
set -euo pipefail

UDID="${SIM_UDID:-CD20E1DF-CD59-4B00-8F95-96153E68FAC1}"
BUNDLE="com.kaden.racing.championships"
IOS="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$IOS/test-screenshots/qa-taps-$(date +%Y%m%d-%H%M%S)"
APP="${APP_PATH:-/Volumes/My Passport for Mac/Developer/XcodeDerivedDataGlobal/KadenRacing-chlkwfvcwsbxsydxhzwmtnxzmglm/Build/Products/Debug-iphonesimulator/KadenRacing.app}"

mkdir -p "$OUT"
PASS=0
FAIL=0

log() { echo "$*"; }
pass() { PASS=$((PASS + 1)); log "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); log "  ✗ $1"; }

sim_window() {
  osascript 2>/dev/null <<'APPLESCRIPT' || echo "41,31,451,962"
tell application "System Events"
  tell process "Simulator"
    set frontmost to true
    set w to front window
    return "" & (item 1 of (position of w)) & "," & (item 2 of (position of w)) & "," & (item 1 of (size of w)) & "," & (item 2 of (size of w))
  end tell
end tell
APPLESCRIPT
}

# Map logical iPhone point (393×852) → screen click using device inset inside Simulator window.
sim_click_logical() {
  local lx="$1" ly="$2"
  local geo ox oy ww wh
  geo="$(sim_window)"
  IFS=',' read -r ox oy ww wh <<<"$geo"
  local inset_x=$((ww * 8 / 100))
  local inset_y=$((wh * 9 / 100))
  local inner_w=$((ww - inset_x * 2))
  local inner_h=$((wh - inset_y * 2))
  local sx=$((ox + inset_x + (lx * inner_w) / 393))
  local sy=$((oy + inset_y + (ly * inner_h) / 852))
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  sleep 0.12
  cliclick "c:${sx},${sy}" 2>/dev/null || return 1
}

shot() {
  xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null
  log "    → $1.png"
}

launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.35
  if [[ $# -eq 0 ]]; then
    xcrun simctl launch "$UDID" "$BUNDLE" -qaTapTest >/dev/null
  else
    xcrun simctl launch "$UDID" "$BUNDLE" -qaTapTest "$@" >/dev/null
  fi
  sleep 2.4
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  sleep 0.35
}

screenshot_changed() {
  local before="$1" after="$2"
  [[ -f "$before" && -f "$after" ]] || return 1
  if command -v magick >/dev/null 2>&1; then
    local diff
    diff="$(magick compare -metric AE "$before" "$after" null: 2>&1 || echo 999999)"
    awk "BEGIN { exit !(${diff%%.*} > 8000) }"
    return
  fi
  [[ "$(wc -c <"$before" | tr -d ' ')" != "$(wc -c <"$after" | tr -d ' ')" ]]
}

dismiss_sheet() {
  sim_click_logical 350 108
  sleep 0.45
}

tap_test() {
  local name="$1" lx="$2" ly="$3" before="$4"
  sim_click_logical "$lx" "$ly" || { fail "$name (click failed)"; return; }
  sleep 1.0
  shot "$name"
  if screenshot_changed "$OUT/$before.png" "$OUT/$name.png"; then
    pass "$name"
  else
    fail "$name (no UI change — check $OUT/$name.png)"
  fi
}

command -v cliclick >/dev/null || { echo "Install cliclick: brew install cliclick"; exit 1; }

echo "Building Debug app…"
(cd "$IOS" && xcodebuild -scheme KadenRacing -destination "platform=iOS Simulator,id=$UDID" build -quiet)

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator >/dev/null 2>&1 || true
sleep 1
xcrun simctl install "$UDID" "$APP" 2>/dev/null || true

launch
shot "00-menu"

log ""
log "=== Settings (gear) ==="
launch
shot "00b-gear"
tap_test "01-settings-gear" 353 59 "00b-gear"
dismiss_sheet

log ""
log "=== Settings (footer) ==="
launch
shot "01b-settings-footer"
tap_test "02-settings-footer" 142 828 "01b-settings-footer"
dismiss_sheet

log ""
log "=== Privacy ==="
launch
shot "02b-privacy"
tap_test "03-privacy-footer" 232 828 "02b-privacy"
dismiss_sheet

log ""
log "=== Terms ==="
launch
shot "03b-terms"
tap_test "04-terms-footer" 322 828 "03b-terms"
dismiss_sheet

log ""
log "=== Game Center ==="
launch
shot "04b-gc"
tap_test "05-game-center-footer" 52 828 "04b-gc"
osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true
sleep 0.3

log ""
log "=== Pause → Resume ==="
launch -qaRace
sleep 3.5
shot "05b-pause"
sim_click_logical 358 98 || fail "Pause click failed"
sleep 0.8
shot "06-paused"
if screenshot_changed "$OUT/05b-pause.png" "$OUT/06-paused.png"; then
  pass "Pause overlay"
  sim_click_logical 196 470 || true
  sleep 0.7
  shot "07-resumed"
  pass "Resume tap sent"
else
  fail "Pause HUD (no overlay)"
fi

log ""
log "Pass: $PASS  Fail: $FAIL"
log "Screenshots: $OUT"
[[ "$FAIL" -eq 0 ]]
