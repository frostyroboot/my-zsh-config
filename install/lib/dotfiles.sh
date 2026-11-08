#!/usr/bin/env bash
# install/lib/dotfiles.sh
# Despliegue/actualización del repo de config y configs de apps.

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

backup_path() {
    local p="$1"
    if [[ -e "$p" || -L "$p" ]]; then
        local backup="${p}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$p" "$backup"
        echo "[dotfiles] backup: $p -> $backup"
    fi
}

# Copia un archivo o directorio del repo a destino, con backup.
deploy_one() {
    local src="$1" dst="$2"
    if [[ ! -e "$src" ]]; then
        echo "[dotfiles] fuente no existe: $src" >&2
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    backup_path "$dst"
    if [[ -d "$src" ]]; then
        cp -r "$src" "$dst"
    else
        cp "$src" "$dst"
    fi
    echo "[dotfiles] desplegado: $src -> $dst"
}

deploy_config() {
    local install_dir="${ZSH_CONFIG:-$HOME/.config/zsh}"
    if [[ -d "$install_dir/.git" ]]; then
        echo "[dotfiles] Actualizando config existente..."
        git -C "$install_dir" pull --ff-only 2>/dev/null || echo "[dotfiles] No se pudo hacer pull (cambios locales?)" >&2
    elif [[ -e "$install_dir" ]]; then
        backup_path "$install_dir"
        echo "[dotfiles] Directorio existente sin git; dejando como está"
    else
        echo "[dotfiles] Clonando config..."
        mkdir -p "$(dirname "$install_dir")"
        git clone --depth 1 https://github.com/frostyroboot/my-zsh-config.git "$install_dir" || echo "[dotfiles] Clone falló" >&2
    fi

    # Desplegar configs de apps
    local cfg="$ROOT_DIR/config"
    if [[ -d "$cfg" ]]; then
        [[ -d "$cfg/atuin" ]] && deploy_one "$cfg/atuin" "$HOME/.config/atuin"
        [[ -f "$cfg/starship.toml" ]] && deploy_one "$cfg/starship.toml" "$HOME/.config/starship.toml"
        [[ -d "$cfg/yazi" ]] && deploy_one "$cfg/yazi" "$HOME/.config/yazi"
        [[ -d "$cfg/nvim" ]] && deploy_one "$cfg/nvim" "$HOME/.config/nvim"
    fi
}

backup_config() {
    local install_dir="${ZSH_CONFIG:-$HOME/.config/zsh}"
    if [[ -e "$install_dir" && ! -d "$install_dir/.git" ]]; then
        backup_path "$install_dir"
    fi
}