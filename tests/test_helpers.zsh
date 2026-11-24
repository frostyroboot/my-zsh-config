# Test portable helpers
source "$ZSH_CONFIG/keybindings/fzf.zsh" 2>/dev/null || true

# _fz_fd should return a non-empty command
fdcmd="$(_fz_fd)"
[[ -n "$fdcmd" ]] || { echo "FAIL: _fz_fd empty"; exit 1; }
echo "_fz_fd=$fdcmd OK"


echo "helpers OK"
