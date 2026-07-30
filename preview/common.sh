#!/usr/bin/env bash
# common.sh - Utilidades compartidas por el sistema de preview
# Cargado por preview.sh y por los handlers/backends

# Constantes (con defaults sensatos)
: "${FZF_PREVIEW_DIR:=$HOME/.config/zsh/preview}"
: "${FZF_PREVIEW_TMP_DIR:=/tmp/fzf-preview-$$}"
: "${FZF_PREVIEW_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview/thumbnails}"
: "${FZF_PREVIEW_FIFO_DIR:=${XDG_RUNTIME_DIR:-/tmp}/fzf-preview}"
: "${FZF_PREVIEW_MAX_FILE_SIZE:=104857600}"  # 100MB
: "${FZF_PREVIEW_THUMB_MAX_DIM:=1920}"

# ====================== DETECCIÓN DE TIPO ======================
# Detecta el tipo de archivo. Salida: directorio|image|video|pdf|audio|
#                                       texto|markdown|json|archive|binario
detect_type() {
    local file="$1"
    [[ -d "$file" ]] && { echo "directory"; return; }
    [[ -L "$file" ]] && file=$(readlink -f "$file" 2>/dev/null || echo "$file")

    local mime
    mime=$(file --brief --dereference --mime-type -- "$file" 2>/dev/null)
    case "$mime" in
        image/*)        echo "image" ;;
        video/*)        echo "video" ;;
        audio/*)        echo "audio" ;;
        application/pdf) echo "pdf" ;;
        application/json) echo "json" ;;
        text/markdown)  echo "markdown" ;;
        text/*)         echo "text" ;;
        application/zip|application/x-tar|application/x-bzip2|application/x-xz|application/gzip|application/x-7z-compressed|application/x-rar|application/vnd.rar)
                        echo "archive" ;;
        application/octet-stream|inode/x-empty)
            # Fallback por extensión
            detect_type_by_ext "$file"
            ;;
        *)              detect_type_by_ext "$file" ;;
    esac
}

# Fallback por extensión cuando `file` no detecta bien
detect_type_by_ext() {
    local file="${1:l}"  # lowercase
    case "$file" in
        # Imágenes
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.svg|*.ico|*.heic|*.avif|*.jxl|*.tiff|*.tif)
            echo "image" ;;
        # Vídeos
        *.mp4|*.mkv|*.webm|*.avi|*.mov|*.wmv|*.flv|*.m4v|*.ogv|*.3gp)
            echo "video" ;;
        # Audio
        *.mp3|*.flac|*.ogg|*.wav|*.opus|*.m4a|*.aac|*.wma)
            echo "audio" ;;
        # PDFs
        *.pdf) echo "pdf" ;;
        # Markdown
        *.md|*.markdown) echo "markdown" ;;
        # JSON
        *.json|*.jsonc|*.json5) echo "json" ;;
        # Archivos
        *.zip|*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.7z|*.rar|*.gz|*.bz2|*.xz|*.lz4|*.zst)
            echo "archive" ;;
        # Ejecutables / objetos
        *.exe|*.dll|*.so|*.dylib|*.o|*.a|*.bin|*.AppImage|*.deb|*.rpm)
            echo "binary" ;;
        *)
            echo "binary"
            ;;
    esac
}

# ====================== HELPERS DE SEGURIDAD ======================

# Comprueba si un archivo es demasiado grande para previsualizar
is_too_large() {
    local file="$1"
    local size
    size=$(get_file_size "$file" 2>/dev/null)
    [[ -n "$size" && "$size" -gt "$FZF_PREVIEW_MAX_FILE_SIZE" ]]
}

# Tamaño portable (GNU/BSD)
get_file_size() {
    if stat --version >/dev/null 2>&1; then
        stat -c%s "$1" 2>/dev/null
    else
        stat -f%z "$1" 2>/dev/null
    fi
}

# mtime portable
get_file_mtime() {
    if stat --version >/dev/null 2>&1; then
        stat -c%Y "$1" 2>/dev/null
    else
        stat -f%m "$1" 2>/dev/null
    fi
}

# Lee un archivo con timeout (para no colgar el preview)
read_with_timeout() {
    local file="$1"
    local lines="${2:-300}"
    timeout 2 head -n "$lines" "$file" 2>/dev/null || echo "[archivo demasiado largo o ilegible]"
}

# Mensaje de error estándar
preview_error() {
    local msg="$1"
    echo "❌ $msg" >&2
}

# Log si está habilitado
_log() {
    [[ "${FZF_PREVIEW_DEBUG:-0}" == "1" ]] && echo "[fzf-preview] $*" >&2
}

# ====================== SELECCIÓN DE BACKEND DE IMAGEN ======================
# Orden de preferencia: kitten (kitty/ghostty nativo) → ueberzugpp → catimg → genérico
# Retorna el nombre de la función de backend a usar (definida en fz-file2preview.sh)
select_img_backend() {
    if command -v kitten >/dev/null 2>&1; then
        echo "kitty_preview"
        return
    fi
    if command -v ueberzugpp >/dev/null 2>&1 || command -v ueberzug >/dev/null 2>&1; then
        echo "ueberzug_preview"
        return
    fi
    if command -v catimg >/dev/null 2>&1; then
        echo "catimg_preview"
        return
    fi
    echo "generic_preview"
}

# Nota: NO usar `export -f` (no es válido en zsh).
# Este archivo es sourced por preview.sh (bash) donde las funciones
# quedan automáticamente disponibles en el subshell bash.
