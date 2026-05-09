# functions/fzf.zsh - Funciones avanzadas con fzf + Kitty icat

# ====================== CONFIGURACIÓN BASE ======================
# Opciones comunes recomendadas
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --height 70% --layout=reverse --border --info=inline"

# ====================== PREVIEW UNIVERSAL (con icat) ======================
fzf_preview() {
    local file="$1"

    # Directorios
    if [[ -d "$file" ]]; then
        eza --tree --level=2 --icons --color=always "$file"
        return
    fi

    # Imágenes (Kitty icat)
    case "$file" in
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.ico|*.svg)
            if command -v kitty >/dev/null 2>&1; then
                kitty +kitten icat --clear --transfer-mode file --place "50x30@0x0" --scale-up "$file" 2>/dev/null || echo "No se pudo mostrar imagen"
                echo "\n--- ${file:t} ---"
                file -b "$file"
                return
            fi
            ;;
    esac

    # Archivos binarios
    if file --mime "$file" | grep -q 'binary'; then
        echo "Binary file"
        file -b "$file"
        return
    fi

    # Archivos de código / texto (bat)
    if command -v bat >/dev/null 2>&1; then
        bat --style=numbers,changes,header --color=always --line-range :300 "$file" 2>/dev/null || cat "$file"
    else
        cat "$file"
    fi
}

# ====================== FUNCIONES MEJORADAS ======================

# Abrir archivo con editor
fe() {
    local file
    file=$(fzf --preview 'fzf_preview {}') && ${EDITOR:-nvim} "$file"
}

# Buscar y previsualizar archivos
ff() {
    fzf --preview 'fzf_preview {}'
}

# Cambiar a directorio (mejorado)
fcd() {
    local dir
    dir=$(fd -t d | fzf --preview 'fzf_preview {}') && cd "$dir"
}

fdz() { fcd; }  # alias corto

# Listar archivos del directorio actual y preview
fl() {
    eza -la --icons --color=always | fzf --ansi --preview 'fzf_preview {}'
}

# Bonus: Buscar en historial y ejecutar
fh() {
    eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# Matar proceso con preview
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf --preview 'echo {}' | awk '{print $2}')
    [[ -n "$pid" ]] && kill -9 "$pid"
}