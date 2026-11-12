#!/usr/bin/env bash
# install/lib/packages.sh
# Instalación de paquetes según manifest TSV y gestor de paquetes detectado.

MANIFEST_FILE="${MANIFEST_FILE:-}"

# Carga el manifest si no está definido.
load_manifest() {
    if [[ -z "$MANIFEST_FILE" ]]; then
        # Buscar relativo al script
        local base
        base="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        MANIFEST_FILE="$base/install/manifests/tools.tsv"
    fi
    if [[ ! -r "$MANIFEST_FILE" ]]; then
        echo "[packages] Manifest no encontrado: $MANIFEST_FILE" >&2
        return 1
    fi
}

# Devuelve el nombre de paquete para un PM (columna 3=apt,4=dnf,5=pacman,6=pkg).
pkg_name_for_pm() {
    local row="$1" pm="$2"
    case "$pm" in
        apt)    echo "$row" | cut -f3 ;;
        dnf)    echo "$row" | cut -f4 ;;
        pacman) echo "$row" | cut -f5 ;;
        pkg)    echo "$row" | cut -f6 ;;
        brew)   echo "$row" | cut -f3 ;; # aproximación
        *)      echo "-" ;;
    esac
}

# Indica si un perfil incluye otro.
profile_includes() {
    local target="$1" tool_profile="$2"
    case "$target" in
        full) [[ "$tool_profile" =~ ^(core|preview|dev|optional)$ ]] ;;
        dev)  [[ "$tool_profile" =~ ^(core|dev)$ ]] ;;
        preview) [[ "$tool_profile" =~ ^(core|preview)$ ]] ;;
        minimal|core) [[ "$tool_profile" == "core" ]] ;;
        *) [[ "$tool_profile" == "$target" ]] ;;
    esac
}

# Instala un paquete con el PM dado.
pm_install() {
    local pm="$1" pkg="$2"
    [[ "$pkg" == "-" || -z "$pkg" ]] && return 1
    case "$pm" in
        apt)    sudo apt-get install -y -qq "$pkg" ;;
        dnf)    sudo dnf install -y "$pkg" ;;
        pacman) sudo pacman -S --noconfirm --needed "$pkg" ;;
        pkg)    pkg install -y "$pkg" ;;
        brew)   brew install "$pkg" ;;
        *)      return 1 ;;
    esac
}

# Instala paquetes de un perfil.
install_packages_for_profile() {
    local profile="$1" pm="$2"
    load_manifest || return 1
    # Actualizar índices una vez (apt)
    if [[ "$pm" == "apt" ]]; then
        sudo apt-get update -qq 2>/dev/null || true
    fi
    local line tool tprofile pkg
    while IFS= read -r line; do
        # saltar comentarios/vacías
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        tool="$(echo "$line" | cut -f1)"
        tprofile="$(echo "$line" | cut -f2)"
        profile_includes "$profile" "$tprofile" || continue
        pkg="$(pkg_name_for_pm "$line" "$pm")"
        if command -v "$tool" >/dev/null 2>&1; then
            echo "[packages] $tool ya instalado, saltando"
            continue
        fi

        local fallback
        fallback="$(echo "$line" | cut -f7)"

        if [[ "$pkg" == "-" || -z "$pkg" ]]; then
            echo "[packages] $tool: sin paquete para $pm"
            if [[ "$fallback" != "none" && "$fallback" != "-" && -n "$fallback" ]]; then
                install_binary "$tool" || true
            fi
            continue
        fi

        echo "[packages] Instalando $tool ($pkg)..."
        if pm_install "$pm" "$pkg"; then
            echo "[packages] $tool OK"
        else
            echo "[packages] $tool FALLÓ" >&2
            if [[ "$fallback" != "none" && "$fallback" != "-" && -n "$fallback" ]]; then
                install_binary "$tool" || true
            fi
        fi
    done < "$MANIFEST_FILE"
}