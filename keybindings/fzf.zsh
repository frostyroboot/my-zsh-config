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
    # Capturar stdout, tomar última línea, limpiar TODAS las escape sequences (CSI, OSC, APC, kitty)
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t f . "$HOME" 2>/dev/null) --query="$LBUFFER" --select-1 --exit-0 -m 2>/dev/null | tail -n1 | sed -E 's/\x1b[][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    local ret=$?
    if [[ $ret -eq 0 && -n "$selected" ]]; then
        LBUFFER="$selected"
    fi
    zle reset-prompt
}
zle -N fz_file_widget
bindkey '^F' fz_file_widget

# Ctrl-T: seleccionar directorio y pegar `cd <dir>` al prompt
fz_cd_widget() {
    local selected
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t d . "$HOME" 2>/dev/null) 2>/dev/null | tail -n1 | sed -E 's/\x1b[][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    local ret=$?
    if [[ $ret -eq 0 && -n "$selected" ]]; then
        LBUFFER="cd ${(q)selected}"
    fi
    zle reset-prompt
}
zle -N fz_cd_widget
bindkey '^T' fz_cd_widget

# Alt-C: liberado (Ctrl-T cubre la misma funcionalidad)
bindkey -r '\ec'
