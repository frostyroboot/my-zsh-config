#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW="$ROOT/preview"

# Source common.sh
# shellcheck source=/dev/null
source "$PREVIEW/common.sh"

pass=0; fail=0
check() {
    local got="$1" exp="$2" name="$3"
    if [[ "$got" == "$exp" ]]; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        echo "FAIL: $name (got='$got' exp='$exp')"
    fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# directory
mkdir -p "$tmpdir/d"
check "$(detect_type "$tmpdir/d")" "directory" "directory"

# text
echo "hello" > "$tmpdir/a.txt"
check "$(detect_type "$tmpdir/a.txt")" "text" "text"

# markdown
echo "# hi" > "$tmpdir/a.md"
check "$(detect_type "$tmpdir/a.md")" "markdown" "markdown"

# json
echo '{"a":1}' > "$tmpdir/a.json"
check "$(detect_type "$tmpdir/a.json")" "json" "json"

# archive
touch "$tmpdir/a.zip"
# zip mime may be application/zip; detect_type_by_ext fallback? file --mime-type on empty zip may differ; test ext fallback via detect_type_by_ext
check "$(detect_type_by_ext "$tmpdir/a.zip")" "archive" "archive ext"

# binary/ext
check "$(detect_type_by_ext "$tmpdir/a.exe")" "binary" "binary ext"

# image ext fallback
check "$(detect_type_by_ext "$tmpdir/a.png")" "image" "image ext"

echo "common.sh tests: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]