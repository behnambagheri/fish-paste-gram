#!/usr/bin/env bash
# Re-vendor the Behnam Bagheri Design System (ds/v1) from the bea.sh repo into docs/ds/v1.
# The site must not hotlink https://bea.sh/ds/v1/, so a pinned copy lives in this repo.
#
# Usage: scripts/sync-ds.sh [git-ref]   (default: main)
# Then bump the ?v= query on the ds stylesheets in docs/index.html.
set -euo pipefail

REPO="behnambagheri/bea.sh"
REF="${1:-main}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/docs/ds"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --quiet --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$TMP/src" 2>/dev/null \
  || { git clone --quiet "https://github.com/$REPO.git" "$TMP/src" && git -C "$TMP/src" checkout --quiet "$REF"; }

COMMIT="$(git -C "$TMP/src" rev-parse HEAD)"
[ -f "$TMP/src/ds/v1/tokens.css" ] || { echo "sync-ds: ds/v1 not found at $REPO@$REF" >&2; exit 1; }

rm -rf "$DEST/v1"
mkdir -p "$DEST"
cp -R "$TMP/src/ds/v1" "$DEST/v1"
# The brand mark (keystone arch) is the bea.sh favicon, not part of ds/v1.
cp "$TMP/src/favicon.svg" "$DEST/bb-mark.svg"

cat >"$DEST/VERSION" <<EOF
source: https://github.com/$REPO/tree/$COMMIT/ds/v1
commit: $COMMIT
synced: $(date -u +%Y-%m-%d)
EOF

echo "sync-ds: vendored $REPO@$COMMIT into docs/ds"
