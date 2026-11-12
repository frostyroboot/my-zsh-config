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

MANIFEST_FILE="$ROOT_DIR/manifests/tools.tsv"
export MANIFEST_FILE

PROFILE="full"
DRY_RUN=0
NO_SHELL=0
YES=0
NVIM_SYNC=0

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
  -h, --help    Esta ayuda
EOF
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
    [[ "$DETECTED_TERMUX" -eq 1 ]] && { echo "[shell] Termux: no se cambia shell automáticamente. Ejecuta 'chsh -s zsh' si lo deseas."; return 0; }
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [[ -z "$zsh_path" ]] && return 0
    if [[ ! -f /etc/shells ]] || ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
    fi
    if [[ "${SHELL:-}" != "$zsh_path" ]]; then
        chsh -s "$zsh_path" || echo "[shell] No se pudo cambiar shell (ejecuta chsh manualmente)" >&2
    fi
}

main() {
    parse_args "$@"
    detect_all

    echo "=== Detección ==="
    echo "OS:       $DETECTED_OS"
    echo "Distro:   $DETECTED_DISTRO"
    echo "PM:       $DETECTED_PM"
    echo "Arch:     $DETECTED_ARCH"
    echo "Termux:   $DETECTED_TERMUX"
    echo "Perfil:   $PROFILE"
    echo "================="

    if [[ "$DETECTED_PM" == "unknown" ]]; then
        echo "[install] Gestor de paquetes desconocido; abortando" >&2
        exit 1
    fi

    maybe_confirm || { echo "Cancelado"; exit 0; }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Se instalarían paquetes del perfil '$PROFILE' con $DETECTED_PM"
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

    echo "=== Deploy config ==="
    backup_config
    deploy_config

    if [[ "$NVIM_SYNC" -eq 1 ]] && command -v nvim >/dev/null 2>&1; then
        echo "=== Neovim sync ==="
        nvim --headless "+Lazy! sync" +qa || echo "[warn] nvim sync falló" >&2
    fi

    echo "=== Shell ==="
    setup_shell

    echo "=== Listo ==="
    echo "Reinicia la terminal o ejecuta: exec zsh"
}

main "$@"