#!/usr/bin/env bash
# Frees ~4GB by removing Cursor's SQLite state DB (composer / indexed chat storage).
# Run ONLY after fully quitting Cursor: Cursor menu → Quit Cursor (⌘Q).
set -euo pipefail

GS="$HOME/Library/Application Support/Cursor/User/globalStorage"

if pgrep -x Cursor >/dev/null 2>&1 || pgrep -if "Cursor.app/Contents/MacOS/Cursor" >/dev/null 2>&1; then
  echo "Cursor is still running. Quit Cursor completely (⌘Q), then run this script again."
  exit 1
fi

echo "Before:"
df -h /System/Volumes/Data | tail -1

rm -f "$GS/state.vscdb" "$GS/state.vscdb-shm" "$GS/state.vscdb-wal"

echo ""
echo "Removed Cursor state database files. Next launch will recreate an empty DB."
echo "After:"
df -h /System/Volumes/Data | tail -1
