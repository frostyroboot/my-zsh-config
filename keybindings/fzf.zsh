# keybindings/fzf.zsh - Keybindings de fzf
# Usa el wrapper de gmou3/fzf-preview que orquesta el daemon de ueberzugpp.
# El wrapper maneja el ciclo de vida del daemon automáticamente.

export FZF_PREVIEW_WRAPPER="${FZF_PREVIEW_DIR:-$ZSH_CONFIG/preview}/fz-wrapper.sh"

# ====================== WIDGETS PERSONALIZADOS ======================
# Los widgets nativos de fzf SOLO existen si FZF_CTRL_T_COMMAND y
# FZF_ALT_C_COMMAND están definidas. Usamos widgets personalizados para
# tener control total: ^F para archivos, ^T para directorios.

# Ctrl-F: seleccionar archivo(s) y pegar al prompt
fz_file_widget() {
    local selected
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t f . 2>/dev/null) --query="$LBUFFER" --select-1 --exit-0 -m)"
    LBUFFER="$selected"
    zle reset-prompt
}
zle -N fz_file_widget
bindkey '^F' fz_file_widget

# Ctrl-T: seleccionar directorio y pegar `cd <dir>` al prompt
fz_cd_widget() {
    local selected
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t d --hidden --follow --exclude .git))"
    LBUFFER="cd ${(q)selected}"
    zle reset-prompt
}
zle -N fz_cd_widget
bindkey '^T' fz_cd_widget

# Alt-C: liberado (Ctrl-T cubre la misma funcionalidad)
bindkey -r '\ec'
