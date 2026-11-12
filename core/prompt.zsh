eval "$(starship init zsh)"

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
    (atuin history list --limit 1 < /dev/null > /dev/null 2>&1 &)
fi