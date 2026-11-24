# keybindings/fzf.zsh - Keybindings de fzf
# Usa el wrapper de gmou3/fzf-preview que orquesta el daemon de ueberzugpp.
# El wrapper maneja el ciclo de vida del daemon automáticamente.

export FZF_PREVIEW_WRAPPER="${FZF_PREVIEW_DIR:-$ZSH_CONFIG/preview}/fz-wrapper.sh"

# Binarios portables (Debian/Ubuntu usan nombres con sufijo)
_fz_fd()  { if command -v fd      >/dev/null 2>&1; then echo fd;      elif command -v fdfind  >/dev/null 2>&1; then echo fdfind;  else echo "find"; fi; }

# ====================== WIDGETS PERSONALIZADOS ======================
# Los widgets nativos de fzf SOLO existen si FZF_CTRL_T_COMMAND y
# FZF_ALT_C_COMMAND están definidas. Usamos widgets personalizados para
# tener control total: ^F para archivos, ^T para directorios.

# Ctrl-F: seleccionar archivo(s) e insertar en la posición del cursor
fz_file_widget() {
    local query left
    local -a selected
    # Extraer solo la palabra bajo el cursor como query inicial de fzf
    query="${LBUFFER:0:$CURSOR}"
    query="${query##* }"
    # Guardar la parte izquierda (sin la palabra que vamos a reemplazar)
    left="${LBUFFER:0:$((CURSOR - ${#query}))}"

    local _fd="$(_fz_fd)"
    local -a input_cmd
    if [[ "$_fd" == "find" ]]; then
        input_cmd=(find "$HOME" -type f -not -path '*/.git/*')
    else
        input_cmd=($_fd -t f --hidden --exclude .git . "$HOME")
    fi

    # Capturar TODAS las selecciones (multi-select) y limpiar escape sequences
    selected=("${(@f)$($FZF_PREVIEW_WRAPPER < <("${input_cmd[@]}" 2>/dev/null) --query="$query" --exit-0 -m 2>/dev/null | sed -E 's/\x1b\[\][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')}")
    if [[ ${#selected[@]} -gt 0 && -n "${selected[1]}" ]]; then
        # Insertar rutas separadas por espacio
        local joined="${(j: :)selected}"
        local inserted="${(q)joined}"
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
    local _fd="$(_fz_fd)"
    if [[ "$_fd" == "find" ]]; then
        selected="$($FZF_PREVIEW_WRAPPER < <(find "$HOME" -type d -not -path '*/.git/*' 2>/dev/null) 2>/dev/null | tail -n1 | sed -E 's/\x1b\[\][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    else
        selected="$($FZF_PREVIEW_WRAPPER < <($_fd -t d --hidden --exclude .git . "$HOME" 2>/dev/null) 2>/dev/null | tail -n1 | sed -E 's/\x1b\[\][()P\\^_][^[:cntrl:]]*([\x07\x1b\\]|\x1b\\)//g')"
    fi
    if [[ -n "$selected" ]]; then
        builtin cd "$selected"
    fi
    zle reset-prompt
}
zle -N fz_cd_widget
bindkey '^T' fz_cd_widget

# Alt-C: liberado (Ctrl-T cubre la misma funcionalidad)
bindkey -r '\ec'
