#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MANIFEST_FILE="$ROOT/install/manifests/tools.tsv"
# shellcheck source=/dev/null
source "$ROOT/install/lib/packages.sh"

# profile_includes
check() { if [[ "$1" == "$2" ]]; then echo "PASS: $3"; else echo "FAIL: $3 (got=$1 exp=$2)"; exit 1; fi; }

check "$(profile_includes full core && echo yes || echo no)" "yes" "full includes core"
check "$(profile_includes minimal preview && echo yes || echo no)" "no" "minimal excludes preview"
check "$(profile_includes dev optional && echo yes || echo no)" "no" "dev excludes optional"

# pkg_name_for_pm
row="fzf	core	fzf	fzf	fzf	fzf	binary	fzf	fzf"
check "$(pkg_name_for_pm "$row" apt)" "fzf" "pkg apt"
check "$(pkg_name_for_pm "$row" pacman)" "fzf" "pkg pacman"

# is_tool_installed (nvm marker)
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    is_tool_installed nvm __nvm__ && echo "PASS: nvm detected" || { echo "FAIL: nvm"; exit 1; }
else
    echo "SKIP: nvm not present"
fi

# tool_bins
check "$(tool_bins "$(grep '^fd	' "$MANIFEST_FILE")")" "fd|fdfind" "fd bins"

echo "packages tests OK"