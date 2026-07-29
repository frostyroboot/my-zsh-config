[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# NOTA: FZF_DEFAULT_OPTS se construye en preview/init.zsh
# Este archivo solo carga key-bindings y completion.

