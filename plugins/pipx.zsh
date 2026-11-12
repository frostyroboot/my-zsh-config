# plugins/pipx.zsh
# Autocompletación para pipx (requiere argcomplete / register-python-argcomplete)

if command -v pipx >/dev/null 2>&1 && command -v register-python-argcomplete >/dev/null 2>&1; then
    if (( $+functions[compdef] )); then
        autoload -U bashcompinit 2>/dev/null
        bashcompinit 2>/dev/null
        eval "$(register-python-argcomplete pipx)" 2>/dev/null
    fi
fi
