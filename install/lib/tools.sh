#!/usr/bin/env bash
# install/lib/tools.sh
# Instalación de frameworks, runtimes y binarios (stubs para fases posteriores).

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo "[tools] oh-my-zsh ya instalado"
        return 0
    fi
    echo "[tools] Instalando oh-my-zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

install_starship() {
    command -v starship >/dev/null 2>&1 && { echo "[tools] starship ya instalado"; return 0; }
    echo "[tools] Instalando starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_atuin() {
    command -v atuin >/dev/null 2>&1 && { echo "[tools] atuin ya instalado"; return 0; }
    echo "[tools] Instalando atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh | sh
}

install_nvm() {
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        echo "[tools] nvm ya instalado"
        return 0
    fi
    echo "[tools] Instalando nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
}

install_pnpm() {
    command -v pnpm >/dev/null 2>&1 && { echo "[tools] pnpm ya instalado"; return 0; }
    if command -v corepack >/dev/null 2>&1; then
        corepack enable && corepack prepare pnpm@latest --activate
    elif command -v npm >/dev/null 2>&1; then
        npm install -g pnpm
    else
        echo "[tools] npm no disponible; saltando pnpm" >&2
    fi
}

install_node() {
    # Carga nvm si está disponible
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh"
    fi
    if ! command -v nvm >/dev/null 2>&1; then
        echo "[tools] nvm no disponible; saltando node" >&2
        return 0
    fi
    if command -v node >/dev/null 2>&1; then
        echo "[tools] node ya instalado ($(node --version))"
        return 0
    fi
    echo "[tools] Instalando Node LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
}

# ---------- Fase 3: binarios / fallbacks ----------

ensure_local_bin() {
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
}

ensure_rust() {
    if command -v cargo >/dev/null 2>&1; then
        return 0
    fi
    echo "[tools] Instalando Rust (rustup)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env" 2>/dev/null || true
    export PATH="$HOME/.cargo/bin:$PATH"
}

# Instala un binario precompilado o via fallback.
install_binary() {
    local tool="$1"
    ensure_local_bin
    echo "[tools] Fallback para $tool..."

    case "$tool" in
        starship)
            curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" ;;
        atuin)
            curl --proto '=https' --tlsv1.2 -LsSf \
                https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh | sh ;;
        zoxide)
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash ;;
        yazi)
            ensure_rust
            cargo install --locked yazi-fm yazi-cli 2>/dev/null || cargo install yazi-fm yazi-cli ;;
        fzf)
            local tmp
            tmp="$(mktemp -d)"
            git clone --depth 1 https://github.com/junegunn/fzf.git "$tmp/fzf"
            "$tmp/fzf/install" --bin
            cp "$tmp/fzf/bin/fzf" "$HOME/.local/bin/fzf"
            chmod +x "$HOME/.local/bin/fzf"
            rm -rf "$tmp" ;;
        # Rust (cargo)
        bat|fd|ripgrep|eza|dust|procs|delta|tokei|hyperfine|bottom|tealdeer|zoxide)
            ensure_rust
            local crate="$tool"
            case "$tool" in
                fd) crate="fd-find" ;;
                ripgrep) crate="ripgrep" ;;
                delta) crate="git-delta" ;;
                bottom) crate="bottom" ;;
            esac
            cargo install "$crate" --locked 2>/dev/null || cargo install "$crate" ;;
        *)
            echo "[tools] Sin fallback automático para $tool" >&2
            return 1 ;;
    esac

    if command -v "$tool" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$tool" ]]; then
        echo "[tools] $tool OK"
        return 0
    fi
    echo "[tools] $tool no quedó instalado" >&2
    return 1
}