#!/usr/bin/env bash
# fz-file2preview.sh - Generador de preview para fzf
# Arquitectura basada en gmou3/fzf-preview (https://github.com/gmou3/fzf-preview)
# Patrón: cada preview es un subshell que escribe al FIFO de ueberzugpp
#          (o a stdout como fallback)

FILE="${1:?file2preview: archivo requerido}"
IMG_PREVIEW="${2:-generic_preview}"
CACHE_DIR="${3:-${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview}"
TMP_IMG="${4:-/tmp/fzf-preview-img}"
UEBERZUG_FIFO="${5:-}"

# Cargar utilidades
# shellcheck source=common.sh
source "${FZF_PREVIEW_DIR:-$HOME/.config/zsh/preview}/common.sh"

# ====================== HELPERS DE CACHÉ ======================
# Genera una clave única basada en mtime + size
cache_key() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local mtime=$(stat -f "%m" "$file" 2>/dev/null)
        local size=$(stat -f "%z" "$file" 2>/dev/null)
    else
        local mtime=$(stat -c "%Y" "$file" 2>/dev/null)
        local size=$(stat -c "%s" "$file" 2>/dev/null)
    fi
    echo "${mtime}_${size}"
}

# Devuelve path del caché si existe, vacío si no
cache_get() {
    local file="$1"
    local key
    key=$(cache_key "$file")
    local cached="$CACHE_DIR/${key}.jpg"
    if [[ -f "$cached" ]]; then
        echo "$cached"
        return 0
    fi
    return 1
}

# Almacena thumbnail en caché
cache_put() {
    local file="$1"
    local src="$2"
    local key
    key=$(cache_key "$file")
    local dest="$CACHE_DIR/${key}.jpg"
    mkdir -p "$CACHE_DIR"
    cp "$src" "$dest" 2>/dev/null && echo "$dest"
}

# ====================== BACKENDS DE PREVIEW ======================
# Backend ueberzug: escribe JSON al FIFO
ueberzug_preview() {
    local file="$1"
    [[ -z "$UEBERZUG_FIFO" || ! -p "$UEBERZUG_FIFO" ]] && {
        # Sin FIFO, fallback a chafa
        chafa_preview "$file"
        return
    }
    echo '{"action": "add", "identifier": "fzf", "x": '"${FZF_PREVIEW_LEFT:-0}"', "y": '"${FZF_PREVIEW_TOP:-0}"', "max_width": '"${FZF_PREVIEW_COLUMNS:-80}"', "max_height": '"${FZF_PREVIEW_LINES:-24}"', "path": "'"$file"'"}' \
        >> "$UEBERZUG_FIFO"
    exit 1  # NO cachear
}

# Backend kitty/ghostty: usa kitten icat (nativo, alta calidad)
kitty_preview() {
    local file="$1"
    command -v kitten >/dev/null 2>&1 || {
        chafa_preview "$file"
        return
    }
    kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
        --place="${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-24}@${FZF_PREVIEW_LEFT:-0}x${FZF_PREVIEW_TOP:-0}" \
        -- "$file" 2>/dev/null
}

# Backend chafa: texto Unicode con color
chafa_preview() {
    local file="$1"
    command -v chafa >/dev/null 2>&1 || {
        generic_preview "$file"
        return
    }
    chafa -s "${FZF_PREVIEW_COLUMNS:-80}x${FZF_PREVIEW_LINES:-24}" --format=symbols -- "$file" 2>/dev/null
}

# Backend catimg: ASCII art
catimg_preview() {
    local file="$1"
    command -v catimg >/dev/null 2>&1 || {
        generic_preview "$file"
        return
    }
    catimg -r 2 -w $((2 * ${FZF_PREVIEW_COLUMNS:-80})) "$file" 2>/dev/null
}

# Fallback: solo file
generic_preview() {
    file -- "$1"
}

# ====================== HANDLERS POR TIPO ======================
# Imagen: auto-orient + resize, cache
preview_image() {
    local file="$1"
    local cached
    if cached=$(cache_get "$file"); then
        # Usar thumbnail cacheado
        $IMG_PREVIEW "$cached"
        return
    fi
    # Generar thumbnail: rotar según EXIF y redimensionar
    local thumb="$TMP_IMG.jpg"
    if command -v magick >/dev/null 2>&1; then
        magick "$file" -auto-orient -resize "x1080>" -quality 85 "$thumb" 2>/dev/null || cp "$file" "$thumb"
    else
        cp "$file" "$thumb" 2>/dev/null
    fi
    if [[ -f "$thumb" ]]; then
        # Cachear
        local cached_path
        cached_path=$(cache_put "$file" "$thumb" 2>/dev/null) || echo "$thumb"
        $IMG_PREVIEW "$cached_path"
        rm -f "$thumb"
    fi
}

# Video: thumbnail con ffmpegthumbnailer, cache
preview_video() {
    local file="$1"
    local cached
    if cached=$(cache_get "$file"); then
        $IMG_PREVIEW "$cached"
        return
    fi
    if ! command -v ffmpegthumbnailer >/dev/null 2>&1; then
        # Fallback: ffmpeg directo (sin seek, compatible con todos los videos)
        if command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -y -i "$file" -vframes 1 -q:v 2 -loglevel error "$TMP_IMG.jpg" 2>/dev/null
        else
            ffprobe -hide_banner -v error -show_format -show_streams -print_format flat "$file" 2>/dev/null | head -40
            return
        fi
    else
        ffmpegthumbnailer -i "$file" -o "$TMP_IMG.jpg" -s 1080 -m 2>/dev/null
    fi
    if [[ -s "$TMP_IMG.jpg" ]]; then
        local cached_path
        cached_path=$(cache_put "$file" "$TMP_IMG.jpg" 2>/dev/null) || echo "$TMP_IMG.jpg"
        $IMG_PREVIEW "$cached_path"
        rm -f "$TMP_IMG.jpg"
    else
        ffprobe -hide_banner -v error -show_format "$file" 2>/dev/null | head -20
    fi
}

# PDF: primera página como thumbnail
preview_pdf() {
    local file="$1"
    local cached
    if cached=$(cache_get "$file"); then
        $IMG_PREVIEW "$cached"
        return
    fi
    if ! command -v pdftoppm >/dev/null 2>&1; then
        pdfinfo "$file" 2>/dev/null || file -- "$file"
        return
    fi
    pdftoppm -singlefile -jpeg -r 100 -f 1 -l 1 "$file" "$TMP_IMG" 2>/dev/null
    if [[ -s "${TMP_IMG}.jpg" ]]; then
        local cached_path
        cached_path=$(cache_put "$file" "${TMP_IMG}.jpg" 2>/dev/null) || echo "${TMP_IMG}.jpg"
        $IMG_PREVIEW "$cached_path"
        rm -f "${TMP_IMG}.jpg"
    else
        pdfinfo "$file" 2>/dev/null
    fi
}

# Audio: cover art con ffmpeg
preview_audio() {
    local file="$1"
    local cached
    if cached=$(cache_get "$file"); then
        $IMG_PREVIEW "$cached"
        return
    fi
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -i "$file" -an -c:v copy "$TMP_IMG.jpg" 2>/dev/null
    fi
    if [[ -s "$TMP_IMG.jpg" ]]; then
        local cached_path
        cached_path=$(cache_put "$file" "$TMP_IMG.jpg" 2>/dev/null) || echo "$TMP_IMG.jpg"
        $IMG_PREVIEW "$cached_path"
        rm -f "$TMP_IMG.jpg"
    else
        mediainfo "$file" 2>/dev/null || file -- "$file"
    fi
}

# EPUB: primera página
preview_epub() {
    local file="$1"
    if command -v epub-thumbnailer >/dev/null 2>&1; then
        local thumb="$TMP_IMG.jpg"
        epub-thumbnailer "$file" "$thumb" "1080" 2>/dev/null
        if [[ -s "$thumb" ]]; then
            $IMG_PREVIEW "$thumb"
            rm -f "$thumb"
        else
            file -- "$file"
        fi
    else
        file -- "$file"
    fi
}

# Directorio: árbol
preview_directory() {
    local dir="$1"
    if command -v eza >/dev/null 2>&1; then
        eza --tree --level=2 --icons --color=always --group-directories-first -- "$dir" 2>/dev/null | head -50
    elif command -v tree >/dev/null 2>&1; then
        tree -L 2 -C -- "$dir" 2>/dev/null | head -50
    else
        ls -la -- "$dir" 2>/dev/null | head -50
    fi
}

# Markdown: glow o bat
preview_markdown() {
    local file="$1"
    if command -v glow >/dev/null 2>&1; then
        glow --width "${FZF_PREVIEW_COLUMNS:-80}" -- "$file" 2>/dev/null
    elif command -v bat >/dev/null 2>&1; then
        bat --style="${BAT_STYLE:-numbers}" --color=always --pager=never --language=markdown -- "$file" 2>/dev/null
    else
        cat -- "$file"
    fi
}

# JSON: jq
preview_json() {
    local file="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -C . -- "$file" 2>/dev/null
    elif command -v bat >/dev/null 2>&1; then
        bat --style="${BAT_STYLE:-numbers}" --color=always --pager=never --language=json -- "$file" 2>/dev/null
    else
        cat -- "$file"
    fi
}

# Archivos comprimidos: lista de contenido
preview_archive() {
    local file="$1"
    case "${file:l}" in
        *.zip) unzip -l -- "$file" 2>/dev/null | head -30 ;;
        *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) tar -tvf -- "$file" 2>/dev/null | head -30 ;;
        *.7z) 7z l -- "$file" 2>/dev/null | head -30 ;;
        *.rar) unrar l -- "$file" 2>/dev/null | head -30 ;;
        *.gz) gzip -l -- "$file" 2>/dev/null ;;
        *.bz2) bzcat -- "$file" 2>/dev/null | head -30 ;;
        *.xz) xzcat -- "$file" 2>/dev/null | head -30 ;;
        *) file -- "$file" ;;
    esac
}

# Texto/código: bat
preview_text() {
    local file="$1"
    # Si es muy grande, leer solo el inicio
    if is_too_large "$file"; then
        echo "⚠️  Archivo grande (>100MB), mostrando primeras líneas"
        read_with_timeout "$file" 100
    else
        if command -v bat >/dev/null 2>&1; then
            bat --style="${BAT_STYLE:-numbers}" --color=always --pager=never -- "$file" 2>/dev/null || cat -- "$file"
        else
            cat -- "$file"
        fi
    fi
}

# Binarios: file
preview_binary() {
    file -- "$1"
}

# ====================== DESPACHADOR PRINCIPAL ======================
# Determinar tipo y llamar al handler apropiado
# detect_type devuelve tipos cortos: directory, image, video, audio, pdf, json, markdown, epub, archive, text, binary
TYPE=$(detect_type "$FILE")

# Limpiar imagen anterior (solo si hay daemon de ueberzug activo)
if [[ -n "$UEBERZUG_FIFO" && -p "$UEBERZUG_FIFO" ]]; then
    echo '{"action": "remove", "identifier": "fzf"}' >> "$UEBERZUG_FIFO" 2>/dev/null || true
fi

# Directorio
if [[ -d "$FILE" ]]; then
    preview_directory "$FILE"
    exit 0
fi

# Despachar por tipo corto (coincide con detect_type en common.sh)
case "$TYPE" in
    image)              preview_image "$FILE" ;;
    video)              preview_video "$FILE" ;;
    audio)              preview_audio "$FILE" ;;
    pdf)                preview_pdf "$FILE" ;;
    json)               preview_json "$FILE" ;;
    markdown)           preview_markdown "$FILE" ;;
    epub)               preview_epub "$FILE" ;;
    archive)            preview_archive "$FILE" ;;
    text)               preview_text "$FILE" ;;
    binary|*)
        # Fallback por extensión para binarios/desconocidos
        case "${FILE:l}" in
            *.epub) preview_epub "$FILE" ;;
            *.zip|*.tar*|*.7z|*.rar|*.gz|*.bz2|*.xz) preview_archive "$FILE" ;;
            *) preview_binary "$FILE" ;;
        esac
        ;;
esac
