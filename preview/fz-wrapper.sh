#!/usr/bin/env bash
# fz-wrapper.sh - Orquestador del ciclo de vida de ueberzugpp para fzf
# Arquitectura basada en gmou3/fzf-preview (https://github.com/gmou3/fzf-preview)
#
# Responsabilidades:
#   1. Crear TMP_DIR y FIFO
#   2. Lanzar daemon ueberzugpp que lee del FIFO (UNA VEZ, persistente)
#   3. Exportar FIFO path para que fz-file2preview.sh pueda escribir
#   4. Ejecutar fzf (como subproceso, NO exec, para que el trap funcione)
#   5. Cleanup al salir (trap + tail --pid=$$ auto-kill)

# ====================== CONFIGURACIÓN ======================
PREVIEW_DIR="${FZF_PREVIEW_DIR:-$HOME/.config/zsh/preview}"
TMP_DIR=$(mktemp -d /tmp/fzf-preview.XXXXXXXXXX) || { echo "[fzf-preview] ERROR: no se pudo crear TMP_DIR" >&2; exit 1; }
export FZF_STATE_FILE="$TMP_DIR/state"
TMP_IMG="$TMP_DIR/preview"
export UEBERZUG_FIFO=""

# Cargar utilidades compartidas (incluye select_img_backend)
source "$PREVIEW_DIR/common.sh"

# Cache
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview"
mkdir -p "$CACHE_DIR"

# Elegir backend de imagen (lógica centralizada en common.sh)
IMG_PREVIEW=$(select_img_backend)
export IMG_PREVIEW

# ====================== INICIAR DAEMON UEBERZUGPP (si aplica) ======================
if [[ "$IMG_PREVIEW" == "ueberzug_preview" ]]; then
    UEBERZUG_FIFO="$TMP_DIR/ueberzug-fifo"
    mkfifo "$UEBERZUG_FIFO"

    # Lanzar daemon con tail -f --pid=$$ (auto-cleanup al salir del wrapper)
    # - tail -f mantiene el FIFO abierto para lectura
    # - --pid=$$ : tail muere cuando el wrapper (PID $$) termina
    # - pipe a ueberzugpp layer que lee JSON del FIFO
    tail -f --pid=$$ "$UEBERZUG_FIFO" 2>/dev/null | ueberzugpp layer --silent &
fi

# ====================== CLEANUP ======================
cleanup() {
    # Limpiar imagen mostrada (si hay daemon de ueberzug)
    if [[ -p "${UEBERZUG_FIFO:-}" ]]; then
        echo '{"action": "remove", "identifier": "fzf"}' >> "$UEBERZUG_FIFO" 2>/dev/null || true
    fi

    # Limpiar caché antiguo (mantener solo los últimos 200 archivos)
    ls -1t "$CACHE_DIR" 2>/dev/null | tail -n +201 | xargs -I {} rm "${CACHE_DIR}/{}" 2>/dev/null || true

    # Eliminar directorio temporal
    rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup HUP INT TERM QUIT EXIT

# ====================== CONFIGURAR FZF ======================
# File listing: fd con archivos
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_ALTERNATE_COMMAND='fd --type d --hidden --follow --exclude .git'

echo "file" > "$FZF_STATE_FILE"

# ====================== EJECUTAR FZF ======================
# NO usar exec fzf (perderíamos el trap)
# fzf se ejecuta como subproceso normal; cuando sale, el trap se ejecuta
fzf --reverse \
    --preview "$PREVIEW_DIR/fz-file2preview.sh {} \"$IMG_PREVIEW\" \"$CACHE_DIR\" \"$TMP_IMG\" \"$UEBERZUG_FIFO\"" \
    --bind 'resize:refresh-preview' \
    --bind 'focus,load:transform-header:file --brief {}'
