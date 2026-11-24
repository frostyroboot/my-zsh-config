export PATH="$PATH:$HOME/.local/bin"
export PATH="$HOME/.opencode/bin:$PATH"

# pnpm (instalador oficial get.pnpm.io)
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# Cargo (Rust) — binarios instalados con `cargo install`
if [[ -d "$HOME/.cargo/bin" ]]; then
    case ":$PATH:" in
      *":$HOME/.cargo/bin:"*) ;;
      *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac
fi
if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env" 2>/dev/null || true
fi

# Nix
if [[ -d "$HOME/.nix-profile/bin" ]]; then
    case ":$PATH:" in
      *":$HOME/.nix-profile/bin:"*) ;;
      *) export PATH="$HOME/.nix-profile/bin:$PATH" ;;
    esac
fi
if [[ -d "/nix/var/nix/profiles/default/bin" ]]; then
    case ":$PATH:" in
      *":/nix/var/nix/profiles/default/bin:"*) ;;
      *) export PATH="/nix/var/nix/profiles/default/bin:$PATH" ;;
    esac
fi

# Deduplicar PATH preservando orden
_dedup_path() {
    local IFS=':' p seen="" out=""
    for p in $PATH; do
        [[ -z "$p" ]] && continue
        case ":$seen:" in
            *":$p:"*) ;;
            *) seen="$seen:$p"; out="${out:+$out:}$p" ;;
        esac
    done
    export PATH="$out"
}
_dedup_path
unset -f _dedup_path
