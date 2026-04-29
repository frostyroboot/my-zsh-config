[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# Default (archivos)
export FZF_DEFAULT_OPTS="
--height=80%
--layout=reverse
--border
--preview 'bat --style=numbers --color=always --line-range :300 {}'
--preview-window=right:60%"

# ALT + C (directorios)
export FZF_ALT_C_OPTS="
--preview 'eza --tree --level=2 --icons {}'
--preview-window=right:60%"

