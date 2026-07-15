eval "$(starship init zsh)"
eval "$(atuin init zsh)"

(atuin history list --limit 1 < /dev/null > /dev/null 2>&1 &)