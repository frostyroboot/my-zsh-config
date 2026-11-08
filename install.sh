#!/usr/bin/env bash
# install.sh — Bootstrap entrypoint (curl | bash)
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/frostyroboot/my-zsh-config/main/install.sh | bash
#   curl ... | bash -s -- --full --yes

set -euo pipefail

REPO_URL="https://github.com/frostyroboot/my-zsh-config.git"
INSTALL_DIR="${ZSH_CONFIG:-$HOME/.config/zsh}"

log() { printf '[install] %s\n' "$*" >&2; }
err() { printf '[install] ERROR: %s\n' "$*" >&2; }

# Detecta un gestor de paquetes disponible (orden de preferencia).
detect_pm_bootstrap() {
    if command -v apt-get >/dev/null 2>&1; then echo apt; return; fi
    if command -v dnf >/dev/null 2>&1; then echo dnf; return; fi
    if command -v pacman >/dev/null 2>&1; then echo pacman; return; fi
    if command -v pkg >/dev/null 2>&1; then echo pkg; return; fi
    if command -v brew >/dev/null 2>&1; then echo brew; return; fi
    echo unknown
}

install_git_if_missing() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    local pm
    pm="$(detect_pm_bootstrap)"
    log "git no encontrado; instalando con $pm..."
    case "$pm" in
        apt)    sudo apt-get update -qq && sudo apt-get install -y -qq git ;;
        dnf)    sudo dnf install -y git ;;
        pacman) sudo pacman -Sy --noconfirm git ;;
        pkg)    pkg install -y git ;;
        brew)   brew install git ;;
        *)      err "No se pudo detectar gestor de paquetes para instalar git"; exit 1 ;;
    esac
}

backup_existing() {
    if [[ -e "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
        local backup
        backup="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
        log "Directorio existente sin git; respaldando en $backup"
        mv "$INSTALL_DIR" "$backup"
    fi
}

clone_or_update() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log "Repositorio existente; actualizando..."
        git -C "$INSTALL_DIR" pull --ff-only || {
            err "No se pudo hacer pull (cambios locales?). Revisa manualmente."
            exit 1
        }
    else
        backup_existing
        log "Clonando $REPO_URL -> $INSTALL_DIR"
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
}

main() {
    install_git_if_missing
    clone_or_update
    if [[ ! -x "$INSTALL_DIR/install/install.sh" ]]; then
        chmod +x "$INSTALL_DIR/install/install.sh" 2>/dev/null || true
    fi
    log "Ejecutando instalador..."
    exec "$INSTALL_DIR/install/install.sh" "$@"
}

main "$@"