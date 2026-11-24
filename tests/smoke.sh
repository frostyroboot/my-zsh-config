#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== zsh syntax =="
find "$ROOT" -name '*.zsh' -print0 | while IFS= read -r -d '' f; do
    zsh -n "$f" || { echo "FAIL: $f"; exit 1; }
done
echo "OK"

echo "== bash syntax =="
for f in "$ROOT"/install.sh "$ROOT"/install/install.sh "$ROOT"/install/lib/*.sh "$ROOT"/preview/*.sh "$ROOT"/preview/cleanup; do
    [[ -f "$f" ]] || continue
    bash -n "$f" || { echo "FAIL: $f"; exit 1; }
done
echo "OK"

echo "== source zshrc (non-interactive) =="
ZSH_CONFIG="$ROOT" zsh -c 'source "'"$ROOT"'/zshrc"; echo SOURCED_OK'

echo "== install dry-run =="
"$ROOT/install.sh" --dry-run --yes >/dev/null
echo "OK"

echo "== portable bins =="
if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then echo "fd OK"; else echo "WARN: fd/fdfind missing"; fi
if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then echo "bat OK"; else echo "WARN: bat/batcat missing"; fi

echo "== common.sh tests =="
"$ROOT/tests/test_common.sh"

echo "== helpers tests =="
ZSH_CONFIG="$ROOT" zsh "$ROOT/tests/test_helpers.zsh"

echo "SMOKE_OK"
