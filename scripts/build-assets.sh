#!/usr/bin/env bash
# Full automated 3D asset pipeline: Blender batch → processed + public GLBs (mobile-oriented).
# Mobile-oriented outputs: triangulation, decimation (cars), Draco mesh compression (when supported),
# Principled PBR materials, wheel pivots + custom props for animation. Engine-side instancing: reuse
# one GLB for many SCNNode clones / MDL asset references — batch does not duplicate geometry on disk.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RAW="${RAW:-$ROOT/assets/raw}"
PROC="${PROC:-$ROOT/assets/processed}"
PUB="${PUB:-$ROOT/public/models}"
# Set KRC_GLTF_DRACO=0 if your runtime GLTF loader does not support Draco mesh compression.
export KRC_GLTF_DRACO="${KRC_GLTF_DRACO:-1}"

resolve_blender() {
  if [[ -n "${BLENDER_BIN:-}" && -x "$BLENDER_BIN" ]]; then
    echo "$BLENDER_BIN"
    return 0
  fi
  local c
  c="$(command -v blender 2>/dev/null || true)"
  if [[ -n "$c" && -x "$c" ]]; then
    # Some installs wrap Blender.app; verify binary exists if wrapper is broken.
    if "$c" --version >/dev/null 2>&1; then echo "$c"; return 0; fi
  fi
  for app in \
    "/Applications/Blender.app/Contents/MacOS/Blender" \
    "$HOME/Applications/Blender.app/Contents/MacOS/Blender"; do
    [[ -x "$app" ]] && echo "$app" && return 0
  done
  return 1
}

if ! BLENDER_BIN="$(resolve_blender)"; then
  echo "ERROR: Blender not found. Install Blender 4.x, ensure 'blender' is on PATH, or export BLENDER_BIN=/path/to/Blender" >&2
  exit 1
fi

mkdir -p "$RAW/cars" "$RAW/city" "$PROC/cars" "$PROC/city" "$PUB/cars" "$PUB/city"

echo "Using Blender: $BLENDER_BIN"
echo "→ Car pipeline (import / optimize / GLB)"
"$BLENDER_BIN" --background --python "$ROOT/tools/blender/car_pipeline.py" -- \
  --raw "$RAW" \
  --processed "$PROC" \
  --public "$PUB"

echo "→ City pipeline (modular GLB modules)"
"$BLENDER_BIN" --background --python "$ROOT/tools/blender/city_pipeline.py" -- \
  --processed "$PROC" \
  --public "$PUB"

echo "Asset build complete."
echo "  Processed: $PROC"
echo "  Public:    $PUB"
