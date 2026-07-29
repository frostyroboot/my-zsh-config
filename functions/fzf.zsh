# functions/fzf.zsh - Funciones de utilidad para fzf
# Usa el wrapper de gmou3/fzf-preview que orquesta el daemon de ueberzugpp.

export FZF_PREVIEW_WRAPPER="${FZF_PREVIEW_DIR:-$ZSH_CONFIG/preview}/fz-wrapper.sh"

# ====================== FUNCIONES DE NAVEGACIÓN ======================

# Abrir archivo con editor
fe() {
    local file
    file="$($FZF_PREVIEW_WRAPPER --query="$1" --select-1 --exit-0)" && ${EDITOR:-nvim} "$file"
}

# Buscar y previsualizar archivos
ff() {
    $FZF_PREVIEW_WRAPPER
}

# Cambiar a directorio
fcd() {
    local dir
    dir="$($FZF_PREVIEW_WRAPPER < <(fd -t d --hidden --follow --exclude .git))" && cd "$dir"
}

fdz() { fcd; }  # alias corto

# Listar archivos del directorio actual y previsualizar
fl() {
    eza -la --icons=always --color=always | $FZF_PREVIEW_WRAPPER --ansi
}

# ====================== HISTORIAL CON ATUIN ======================

# Buscar en historial (Ctrl-R ya está bindeado por atuin init en core/prompt.zsh)
fh() {
    eval "$(atuin search --interactive --)"
}

# ====================== PROCESOS ======================

# Matar proceso con preview
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | $FZF_PREVIEW_WRAPPER --header 'Select to TERM (Enter=SIGTERM, fallback SIGKILL)' | awk '{print $2}')
    [[ -z "$pid" ]] && return
    kill "$pid" 2>/dev/null || kill -9 "$pid"
}
