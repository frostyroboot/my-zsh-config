# keybindings/fzf.zsh - Keybindings de fzf
# Usa el wrapper de gmou3/fzf-preview que orquesta el daemon de ueberzugpp.
# El wrapper maneja el ciclo de vida del daemon automáticamente.

export FZF_PREVIEW_WRAPPER="${FZF_PREVIEW_DIR:-$ZSH_CONFIG/preview}/fz-wrapper.sh"

# ====================== WIDGETS PERSONALIZADOS ======================
# Los widgets nativos de fzf SOLO existen si FZF_CTRL_T_COMMAND y
# FZF_ALT_C_COMMAND están definidas. Usamos widgets personalizados para
# tener control total: ^F para archivos, ^T para directorios.

# Ctrl-F: seleccionar archivo(s) e insertar en la posición del cursor
fz_file_widget() {
    local selected query left
    # Extraer solo la palabra bajo el cursor como query inicial de fzf
    query="${LBUFFER:0:$CURSOR}"
    query="${query##* }"
    # Guardar la parte izquierda (sin la palabra que vamos a reemplazar)
    left="${LBUFFER:0:$((CURSOR - ${#query}))}"
    # Capturar stdout, tomar última línea, limpiar TODAS las escape sequences (CSI, OSC, APC, kitty)
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t f --hidden --exclude .git . "$HOME" 2>/dev/null) --query="$query" --select-1 --exit-0 -m 2>/dev/null | tail -n1 | sed -E 's/\x1b[][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    local ret=$?
    if [[ $ret -eq 0 && -n "$selected" ]]; then
        # Insertar en la posición del cursor (reemplaza solo la palabra bajo el cursor)
        local inserted="${(q)selected}"
        LBUFFER="${left}${inserted}${LBUFFER:$CURSOR}"
        CURSOR=$(( ${#left} + ${#inserted} ))
    fi
    zle reset-prompt
}
zle -N fz_file_widget
bindkey '^F' fz_file_widget

# Ctrl-T: seleccionar directorio y hacer cd automáticamente
fz_cd_widget() {
    local selected
    selected="$($FZF_PREVIEW_WRAPPER < <(fd -t d --hidden --exclude .git . "$HOME" 2>/dev/null) 2>/dev/null | tail -n1 | sed -E 's/\x1b[][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    if [[ -n "$selected" ]]; then
        builtin cd "$selected"
    fi
    zle reset-prompt
}
zle -N fz_cd_widget
bindkey '^T' fz_cd_widget

# Alt-C: liberado (Ctrl-T cubre la misma funcionalidad)
bindkey -r '\ec'
