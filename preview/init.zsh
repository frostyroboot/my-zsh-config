# preview/init.zsh - Integración con fzf (arquitectura gmou3/fzf-preview)
# Adoptamos la arquitectura de gmou3/fzf-preview que usa un wrapper
# (fz-wrapper.sh) que orquesta el ciclo de vida del daemon de ueberzugpp.
#
# Patrón clave: tail -f --pid=$$ | ueberzugpp layer
#   - tail mantiene el FIFO abierto para lectura
#   - --pid=$$ hace auto-cleanup cuando el wrapper sale
#   - Sin setsid, sin disown

# ====================== CONFIGURACIÓN ======================

# Paths
export FZF_PREVIEW_DIR="${FZF_PREVIEW_DIR:-$ZSH_CONFIG/preview}"
export FZF_PREVIEW_SCRIPT="$FZF_PREVIEW_DIR/fz-file2preview.sh"  # llamado por fzf
export FZF_PREVIEW_WRAPPER="$FZF_PREVIEW_DIR/fz-wrapper.sh"        # llama a fzf

# Comportamiento
export FZF_PREVIEW_MAX_FILE_SIZE="${FZF_PREVIEW_MAX_FILE_SIZE:-104857600}"  # 100MB
export FZF_PREVIEW_DEBUG="${FZF_PREVIEW_DEBUG:-0}"

# ====================== FZF_DEFAULT_OPTS ======================
# El wrapper es el que ejecuta fzf con todas las opciones.
# Mantenemos FZF_DEFAULT_OPTS para opciones de layout que aplican también
# fuera del wrapper (e.g., si el usuario invoca fzf directamente).

_preview_height="--height=80%"
_preview_layout="--layout=reverse"
_preview_border="--border"
_preview_window="--preview-window=right:60%"

# Solo añadir si no están ya presentes
_add_opt_if_missing() {
    local opt="$1"
    local opt_name="${opt%%=*}"
    if [[ "$FZF_DEFAULT_OPTS" == *"$opt_name"* ]]; then
        return 1
    fi
    echo "$opt"
}

_new_opts=""
for opt in "$_preview_height" "$_preview_layout" "$_preview_border" "$_preview_window"; do
    if added=$(_add_opt_if_missing "$opt"); then
        [[ -n "$_new_opts" ]] && _new_opts+=" "
        _new_opts+="$added"
    fi
done

if [[ -z "$FZF_DEFAULT_OPTS" ]]; then
    export FZF_DEFAULT_OPTS="$_new_opts"
else
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $_new_opts"
fi

# ====================== LIMPIEZA DE DAEMONS HUÉRFANOS EN SHELL EXIT ======================

# Si fzf muere abruptamente, los daemons de ueberzugpp pueden quedar.
# El wrapper ya tiene su propio cleanup via trap, pero por si acaso
# añadimos un fallback al logout de la shell (zshexit_functions).

_preview_shell_exit() {
    [[ -x "$FZF_PREVIEW_DIR/cleanup" ]] && "$FZF_PREVIEW_DIR/cleanup" 2>/dev/null
}

if [[ -z "${_PREVIEW_TRAP_INSTALLED:-}" ]]; then
    zshexit_functions+=(_preview_shell_exit)
    _PREVIEW_TRAP_INSTALLED=1
fi

# Mensaje de estado (solo si debug)
if [[ "$FZF_PREVIEW_DEBUG" == "1" ]]; then
    print -u2 "[fzf-preview] init OK | dir=$FZF_PREVIEW_DIR | wrapper=$FZF_PREVIEW_WRAPPER"
fi
