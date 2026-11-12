#!/usr/bin/env bash
# install/lib/tools.sh
# Instalación de frameworks, runtimes y binarios (stubs para fases posteriores).

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo "[tools] oh-my-zsh ya instalado"
    else
        echo "[tools] Instalando oh-my-zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        echo "[tools] Instalando zsh-syntax-highlighting..."
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
            || echo "[warn] zsh-syntax-highlighting falló" >&2
    fi
}

install_starship() {
    command -v starship >/dev/null 2>&1 && { echo "[tools] starship ya instalado"; return 0; }
    echo "[tools] Instalando starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_atuin() {
    command -v atuin >/dev/null 2>&1 && { echo "[tools] atuin ya instalado"; return 0; }
    ensure_local_bin
    local arch asset url tmp
    arch="$(uname -m)"
    case "$arch" in
        x86_64) asset="atuin-x86_64-unknown-linux-gnu.tar.gz" ;;
        aarch64) asset="atuin-aarch64-unknown-linux-gnu.tar.gz" ;;
        *) asset="" ;;
    esac
    if [[ -n "$asset" ]]; then
        echo "[tools] Instalando atuin (binario precompilado)..."
        url="https://github.com/atuinsh/atuin/releases/latest/download/$asset"
        tmp="$(mktemp -d)"
        if curl -fsSL "$url" -o "$tmp/atuin.tar.gz" 2>/dev/null; then
            if tar -xzf "$tmp/atuin.tar.gz" -C "$tmp" 2>/dev/null; then
                if [[ -f "$tmp/atuin" ]]; then
                    cp "$tmp/atuin" "$HOME/.local/bin/atuin"
                    chmod +x "$HOME/.local/bin/atuin"
                fi
            fi
        fi
        rm -rf "$tmp"
        if command -v atuin >/dev/null 2>&1; then
            echo "[tools] atuin OK"
            return 0
        fi
    fi
    echo "[tools] Fallback installer para atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf \
        https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh | sh
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
    # Limpiar builds antiguos y redirigir temporales (evitar /tmp pequeño)
    rm -rf /tmp/cargo-install* 2>/dev/null || true
    mkdir -p "$HOME/.cache/tmp" "$HOME/.cache/cargo-target"
    export TMPDIR="$HOME/.cache/tmp"
    export CARGO_TARGET_DIR="$HOME/.cache/cargo-target"

    # Asegurar toolchain C (linker cc) incluso si cargo ya está instalado
    if command -v apt-get >/dev/null 2>&1; then
        command -v cc >/dev/null 2>&1 || sudo apt-get install -y -qq build-essential
    elif command -v dnf >/dev/null 2>&1; then
        command -v cc >/dev/null 2>&1 || sudo dnf install -y gcc make
    elif command -v pacman >/dev/null 2>&1; then
        command -v cc >/dev/null 2>&1 || sudo pacman -S --noconfirm --needed base-devel
    fi
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
            ensure_local_bin
            local arch asset url tmp
            arch="$(uname -m)"
            case "$arch" in
                x86_64)  asset="yazi-x86_64-unknown-linux-gnu.zip" ;;
                aarch64) asset="yazi-aarch64-unknown-linux-gnu.zip" ;;
                *)       asset="" ;;
            esac
            if [[ -n "$asset" ]]; then
                echo "[tools] Instalando yazi (binario precompilado)..."
                url="https://github.com/sxyazi/yazi/releases/latest/download/$asset"
                tmp="$(mktemp -d)"
                if curl -fsSL "$url" -o "$tmp/yazi.zip" 2>/dev/null; then
                    if command -v python3 >/dev/null 2>&1; then
                        python3 -m zipfile -e "$tmp/yazi.zip" "$tmp/yazi" >/dev/null 2>&1
                    elif command -v unzip >/dev/null 2>&1; then
                        unzip -q "$tmp/yazi.zip" -d "$tmp/yazi" 2>/dev/null
                    fi
                    if [[ -f "$tmp/yazi/yazi" ]]; then
                        cp "$tmp/yazi/yazi" "$HOME/.local/bin/yazi"
                        chmod +x "$HOME/.local/bin/yazi"
                    fi
                    if [[ -f "$tmp/yazi/ya" ]]; then
                        cp "$tmp/yazi/ya" "$HOME/.local/bin/ya"
                        chmod +x "$HOME/.local/bin/ya"
                    fi
                fi
                rm -rf "$tmp"
                if command -v yazi >/dev/null 2>&1; then
                    echo "[tools] yazi OK"
                    return 0
                fi
            fi
            echo "[tools] Fallback cargo para yazi..."
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
                dust) crate="du-dust" ;;
                ripgrep) crate="ripgrep" ;;
                delta) crate="git-delta" ;;
                bottom) crate="bottom" ;;
            esac
            cargo install "$crate" --locked 2>/dev/null || cargo install "$crate" ;;
        *)
            echo "[tools] Sin fallback automático para $tool" >&2
            return 1 ;;
    esac

    local check_bin="$tool"
    [[ "$tool" == "bottom" ]] && check_bin="btm"
    if command -v "$check_bin" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$check_bin" ]] || [[ -x "$HOME/.cargo/bin/$check_bin" ]]; then
        echo "[tools] $tool OK"
        return 0
    fi
    echo "[tools] $tool no quedó instalado" >&2
    return 1
}