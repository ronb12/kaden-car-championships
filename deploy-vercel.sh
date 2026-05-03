#!/usr/bin/env bash
# Deploy without scanning Desktop/iCloud paths (fixes ETIMEDOUT on `vercel deploy`).
# Also shrink upload: local dist/ is ignored — Vercel runs `npm run build` remotely.
#
# Prereqs: ~5GB+ free disk (almost-full disks often cause ETIMEDOUT). Then:
#   chmod +x deploy-vercel.sh && ./deploy-vercel.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="${TMPDIR:-/tmp}/krc-vercel-stage-$$"

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

echo "Staging copy under ${STAGE} ..."
mkdir -p "$STAGE"
# Exclude paths that iCloud/Desktop sometimes mmap-timeout on rsync, plus non-deploy junk.
rsync -a \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude '.cursor/' \
  --exclude '.gitignore' \
  --exclude 'ios/' \
  --exclude 'assets/' \
  --exclude 'tools/' \
  --exclude 'scripts/' \
  --exclude 'last-night-detailing/' \
  --exclude 'app-store-ipad-screenshots/' \
  --exclude 'dist/' \
  --exclude '.DS_Store' \
  --exclude '*.placeholder.*' \
  --exclude '*.redesign-backup.*' \
  --exclude '*original.placeholder*' \
  --exclude 'garage 2.html' \
  --exclude 'package.original.placeholder.json' \
  --exclude 'package.redesign-backup.json' \
  --exclude 'garage-cars/* 2.png' \
  --exclude 'garage-cars/contact-sheet*.jpg' \
  --exclude '.vercel/' \
  "$ROOT/" "$STAGE/"

cd "$STAGE"
echo "npm install ..."
npm install --omit=dev

# Staged copy intentionally omits .vercel/ (often mmap-timeouts on Desktop/iCloud).
# Recreate the link here (writes fresh files under /tmp only).
PROJ="${VERCEL_PROJECT_NAME:-kaden-car-championships}"
echo "vercel link → project '${PROJ}' ..."
# shellcheck disable=SC2086
vercel link --yes ${VERCEL_TEAM:+--team "$VERCEL_TEAM"} --project "$PROJ"

echo "vercel deploy --prod ..."
vercel deploy --prod --yes

echo "Deploy finished."
