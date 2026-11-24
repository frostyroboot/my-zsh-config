#!/usr/bin/env bash
# install/install.sh — Orquestador principal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar librerías
# shellcheck source=lib/detect.sh
. "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/packages.sh
. "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/tools.sh
. "$SCRIPT_DIR/lib/tools.sh"
# shellcheck source=lib/dotfiles.sh
. "$SCRIPT_DIR/lib/dotfiles.sh"

MANIFEST_FILE="$ROOT_DIR/install/manifests/tools.tsv"
export MANIFEST_FILE

PROFILE="full"
DRY_RUN=0
NO_SHELL=0
YES=0
NVIM_SYNC=0
WITH_NIX="${WITH_NIX:-0}"
WITH_CARGO="${WITH_CARGO:-0}"
CREATE_SYMLINKS="${CREATE_SYMLINKS:-0}"
INTERACTIVE="${INTERACTIVE:-1}"

usage() {
    cat <<EOF
Uso: install.sh [opciones]
  --minimal     Solo core (zsh + remplazos básicos)
  --preview     core + herramientas de preview
  --dev         core + dev (node/pnpm/nvim)
  --full        Todo (por defecto)
  --dry-run     No instala, solo muestra
  --no-shell    No cambia el shell por defecto
  --nvim-sync   Bootstrap de plugins de Neovim (headless)
  --yes         No pedir confirmación
  --with-nix    Habilita instalación via Nix (opt-in)
  --with-cargo  Habilita instalación via Cargo/Rust (opt-in)
  --symlinks    Crea symlinks de conveniencia (fd->fdfind, bat->batcat)
  --no-interactive  Desactiva prompts TUI
  -h, --help    Esta ayuda
EOF
}

# Prompt TUI simple (solo si TTY)
tui_ask() {
    local question="$1" default="${2:-n}"
    if [[ "$INTERACTIVE" -ne 1 ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    if [[ ! -t 0 && ! -t 1 ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    local ans
    local prompt="$question [$default] "
    if [[ -t 0 ]]; then
        read -r -p "$prompt" ans
    elif [[ -r /dev/tty && -w /dev/tty ]]; then
        printf "%s" "$prompt" >/dev/tty
        read -r ans </dev/tty || true
    else
        ans="$default"
    fi
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[yY]$ ]]
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --minimal) PROFILE="minimal" ;;
            --preview) PROFILE="preview" ;;
            --dev)     PROFILE="dev" ;;
            --full)    PROFILE="full" ;;
            --dry-run) DRY_RUN=1 ;;
            --no-shell) NO_SHELL=1 ;;
            --nvim-sync) NVIM_SYNC=1 ;;
            --yes|-y)  YES=1 ;;
            --with-nix) WITH_NIX=1 ;;
            --with-cargo) WITH_CARGO=1 ;;
            --symlinks) CREATE_SYMLINKS=1 ;;
            --no-interactive) INTERACTIVE=0 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Opción desconocida: $1" >&2; usage; exit 1 ;;
        esac
        shift
    done
}

maybe_confirm() {
    [[ "$YES" -eq 1 ]] && return 0
    [[ "$DRY_RUN" -eq 1 ]] && return 0
    local ans
    if [[ -t 0 ]]; then
        read -r -p "¿Continuar con perfil '$PROFILE'? [y/N] " ans
    elif [[ -t 1 && -r /dev/tty && -w /dev/tty ]]; then
        printf "¿Continuar con perfil '%s'? [y/N] " "$PROFILE" >/dev/tty
        read -r ans </dev/tty || true
    else
        echo "[install] Entorno no interactivo: usa --yes para confirmar." >&2
        return 1
    fi
    [[ "$ans" =~ ^[yY]$ ]]
}

setup_shell() {
    [[ "$NO_SHELL" -eq 1 ]] && return 0
    [[ "$DETECTED_TERMUX" -eq 1 ]] && {
        echo "[shell] Termux detectado: no se cambia shell automáticamente."
        echo "[shell] Para usar zsh como shell por defecto ejecuta: chsh -s zsh"
        echo "[shell] (o edita ~/.termux/termux.properties y añade 'shell zsh')"
        return 0
    }
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [[ -z "$zsh_path" ]] && { echo "[shell] zsh no encontrado en PATH"; return 0; }

    # Si ya es el shell actual, no hacer nada
    if [[ "${SHELL:-}" == "$zsh_path" ]]; then
        echo "[shell] Tu shell ya es zsh ($zsh_path). No se requiere cambio."
        return 0
    fi

    # Asegurar que zsh esté en /etc/shells
    if [[ ! -f /etc/shells ]] || ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
    fi

    echo "[shell] Cambiando shell por defecto a $zsh_path ..."
    if chsh -s "$zsh_path"; then
        echo "[shell] OK. Cierra sesión y vuelve a entrar para aplicar."
    else
        echo "[shell] No se pudo cambiar automáticamente (chsh falló)." >&2
        echo "[shell] Cámbialo manualmente con: chsh -s $zsh_path" >&2
        echo "[shell] O edita /etc/passwd si tienes permisos." >&2
    fi
}

main() {
    # Liberar espacio temporal (best effort)
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get clean 2>/dev/null || true
    fi
    rm -rf /tmp/cargo-install* 2>/dev/null || true

    parse_args "$@"
    detect_all

    echo "=== Detección ==="
    echo "OS:       $DETECTED_OS"
    echo "Distro:   $DETECTED_DISTRO"
    echo "PM:       $DETECTED_PM"
    echo "Arch:     $DETECTED_ARCH"
    echo "Termux:   $DETECTED_TERMUX"
    echo "Perfil:   $PROFILE"
    echo "Nix:      $WITH_NIX"
    echo "Cargo:    $WITH_CARGO"
    echo "================="

    if [[ "$DETECTED_PM" == "unknown" ]]; then
        echo "[install] Gestor de paquetes desconocido; abortando" >&2
        exit 1
    fi

    # Prompts TUI para opciones pesadas (solo si interactivo y no se pasaron flags)
    if [[ "$INTERACTIVE" -eq 1 && "$YES" -ne 1 ]]; then
        if [[ "$WITH_NIX" -eq 0 ]]; then
            if tui_ask "¿Habilitar instalación via Nix (nvim latest, glow, etc.)? (puede ser lento)" "n"; then
                WITH_NIX=1
            fi
        fi
        if [[ "$WITH_CARGO" -eq 0 ]]; then
            if tui_ask "¿Habilitar instalación via Cargo/Rust para opcionales (dust, procs, ...)? (requiere rust)" "n"; then
                WITH_CARGO=1
            fi
        fi
        if [[ "$CREATE_SYMLINKS" -eq 0 ]]; then
            if tui_ask "¿Crear symlinks de conveniencia (fd->fdfind, bat->batcat)?" "y"; then
                CREATE_SYMLINKS=1
            fi
        fi
    fi

    export WITH_NIX WITH_CARGO CREATE_SYMLINKS INTERACTIVE

    maybe_confirm || { echo "Cancelado"; exit 0; }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Se instalarían paquetes del perfil '$PROFILE' con $DETECTED_PM"
        echo "[dry-run] WITH_NIX=$WITH_NIX WITH_CARGO=$WITH_CARGO CREATE_SYMLINKS=$CREATE_SYMLINKS"
        echo "[dry-run] Fin."
        exit 0
    fi

    echo "=== Instalando paquetes ==="
    install_packages_for_profile "$PROFILE" "$DETECTED_PM"

    echo "=== Frameworks ==="
    install_oh_my_zsh || echo "[warn] oh-my-zsh falló" >&2
    install_starship || echo "[warn] starship falló" >&2
    install_atuin || echo "[warn] atuin falló" >&2

    # Dev runtimes para perfiles dev/full
    if [[ "$PROFILE" == "dev" || "$PROFILE" == "full" ]]; then
        install_nvm || echo "[warn] nvm falló" >&2
        install_node || echo "[warn] node falló" >&2
        install_pnpm || echo "[warn] pnpm falló" >&2
    fi

    # Symlinks de conveniencia
    if [[ "$CREATE_SYMLINKS" -eq 1 ]]; then
        echo "=== Symlinks ==="
        create_symlinks || echo "[warn] symlinks fallaron" >&2
    fi

    echo "=== Deploy config ==="
    backup_config
    deploy_config

    if [[ "$NVIM_SYNC" -eq 1 ]] && command -v nvim >/dev/null 2>&1; then
        echo "=== Neovim sync ==="
        nvim --headless "+Lazy! sync" +qa || echo "[warn] nvim sync falló" >&2
    fi

    echo "=== Shell ==="
    setup_shell

    print_install_summary

    echo "=== Listo ==="
    echo "Reinicia la terminal o ejecuta: exec zsh"
}

main "$@"