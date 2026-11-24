#!/usr/bin/env bash
# install/lib/packages.sh
# Instalación de paquetes según manifest TSV y gestor de paquetes detectado.

MANIFEST_FILE="${MANIFEST_FILE:-}"

# Opciones globales (pueden venir del entorno o de install.sh)
: "${WITH_NIX:=0}"
: "${WITH_CARGO:=0}"
: "${CREATE_SYMLINKS:=0}"
: "${INTERACTIVE:=1}"

# Resultados de instalación (para resumen final)
declare -a PKG_INSTALLED=() PKG_PRESENT=() PKG_FAILED=() PKG_SKIPPED=() PKG_OMITTED=()

# Carga el manifest si no está definido.
load_manifest() {
    if [[ -z "$MANIFEST_FILE" ]]; then
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

# Binarios reales de una fila (columna 9).
tool_bins() {
    local row="$1"
    echo "$row" | cut -f9
}

# Comprueba si la herramienta ya está instalada (por binarios o casos especiales).
is_tool_installed() {
    local tool="$1" bins="$2"
    case "$tool" in
        nvm)
            [[ -s "$HOME/.nvm/nvm.sh" ]] && return 0
            return 1 ;;
        zsh-syntax-highlighting)
            [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]] && return 0
            return 1 ;;
        *)
            local b
            IFS='|' read -ra _bins <<< "$bins"
            for b in "${_bins[@]}"; do
                [[ -z "$b" || "$b" == "-" ]] && continue
                if command -v "$b" >/dev/null 2>&1; then
                    return 0
                fi
            done
            return 1 ;;
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
    local line tool tprofile pkg fallback nix_attr bins
    while IFS= read -r line; do
        # saltar comentarios/vacías
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        tool="$(echo "$line" | cut -f1)"
        tprofile="$(echo "$line" | cut -f2)"
        profile_includes "$profile" "$tprofile" || continue
        pkg="$(pkg_name_for_pm "$line" "$pm")"
        fallback="$(echo "$line" | cut -f7)"
        nix_attr="$(echo "$line" | cut -f8)"
        bins="$(tool_bins "$line")"
        [[ -z "$bins" || "$bins" == "-" ]] && bins="$tool"

        if is_tool_installed "$tool" "$bins"; then
            echo "[packages] $tool ya instalado, saltando"
            PKG_PRESENT+=("$tool")
            continue
        fi

        # Sin paquete para este PM
        if [[ "$pkg" == "-" || -z "$pkg" ]]; then
            echo "[packages] $tool: sin paquete para $pm"
            local installed=0
            # Fallbacks "ligeros" (binary/installer) siempre permitidos
            if [[ "$fallback" == "binary" || "$fallback" == "installer" ]]; then
                if install_binary "$tool" 2>/dev/null; then
                    installed=1
                fi
            fi
            # Fallback cargo (solo si habilitado)
            if [[ "$installed" -eq 0 && "$fallback" == "cargo" && "$WITH_CARGO" -eq 1 ]]; then
                if install_binary "$tool" 2>/dev/null; then
                    installed=1
                fi
            fi
            # Fallback cargo sin habilitar: avisar
            if [[ "$installed" -eq 0 && "$fallback" == "cargo" && "$WITH_CARGO" -ne 1 ]]; then
                echo "[packages] $tool requiere cargo (omitido; usa --with-cargo)" >&2
                PKG_OMITTED+=("$tool (cargo)")
                continue
            fi
            # Nix fallback (solo si habilitado)
            if [[ "$installed" -eq 0 && "$nix_attr" != "-" && "$nix_attr" != "none" && -n "$nix_attr" && "$WITH_NIX" -eq 1 ]]; then
                if install_via_nix "$nix_attr" 2>/dev/null; then
                    installed=1
                fi
            fi
            if [[ "$installed" -eq 0 && "$nix_attr" != "-" && "$nix_attr" != "none" && -n "$nix_attr" && "$WITH_NIX" -ne 1 ]]; then
                echo "[packages] $tool requiere nix (omitido; usa --with-nix)" >&2
                PKG_OMITTED+=("$tool (nix)")
                continue
            fi
            if is_tool_installed "$tool" "$bins"; then
                echo "[packages] $tool OK"
                PKG_INSTALLED+=("$tool")
            elif [[ "$fallback" == "none" && ( "$nix_attr" == "-" || "$nix_attr" == "none" || -z "$nix_attr" ) ]]; then
                echo "[packages] $tool sin soporte automático en $pm (omitido)" >&2
                PKG_OMITTED+=("$tool (sin soporte)")
            else
                echo "[packages] $tool no quedó instalado" >&2
                PKG_FAILED+=("$tool")
            fi
            continue
        fi

        echo "[packages] Instalando $tool ($pkg)..."
        if pm_install "$pm" "$pkg"; then
            echo "[packages] $tool OK"
            # Verificar binario real
            if is_tool_installed "$tool" "$bins"; then
                PKG_INSTALLED+=("$tool")
            else
                # Paquete instalado pero binario con sufijo (Debian) -> OK igual
                PKG_INSTALLED+=("$tool")
            fi
        else
            echo "[packages] $tool FALLÓ (pm)" >&2
            local installed=0
            if [[ "$fallback" != "none" && "$fallback" != "-" && -n "$fallback" ]]; then
                if [[ "$fallback" == "cargo" ]]; then
                    [[ "$WITH_CARGO" -eq 1 ]] && install_binary "$tool" >/dev/null 2>&1 && installed=1
                else
                    install_binary "$tool" >/dev/null 2>&1 && installed=1
                fi
            fi
            if [[ "$installed" -eq 0 && "$nix_attr" != "-" && "$nix_attr" != "none" && -n "$nix_attr" && "$WITH_NIX" -eq 1 ]]; then
                install_via_nix "$nix_attr" >/dev/null 2>&1 && installed=1
            fi
            if is_tool_installed "$tool" "$bins"; then
                PKG_INSTALLED+=("$tool")
            else
                PKG_FAILED+=("$tool")
            fi
        fi
    done < "$MANIFEST_FILE"
}

# Resumen de instalación
print_install_summary() {
    echo ""
    echo "=== Resumen de instalación ==="
    echo "Ya presentes: ${#PKG_PRESENT[@]}"
    [[ ${#PKG_PRESENT[@]} -gt 0 ]] && printf '  %s\n' "${PKG_PRESENT[@]}"
    echo "Instaladas:   ${#PKG_INSTALLED[@]}"
    [[ ${#PKG_INSTALLED[@]} -gt 0 ]] && printf '  %s\n' "${PKG_INSTALLED[@]}"
    echo "Omitidas:     ${#PKG_OMITTED[@]}"
    [[ ${#PKG_OMITTED[@]} -gt 0 ]] && printf '  %s\n' "${PKG_OMITTED[@]}"
    echo "Fallidas:     ${#PKG_FAILED[@]}"
    if [[ ${#PKG_FAILED[@]} -gt 0 ]]; then
        printf '  %s\n' "${PKG_FAILED[@]}"
        echo ""
        echo "Sugerencias manuales:"
        for t in "${PKG_FAILED[@]}"; do
            echo "  - $t: revisa paquete para tu distro o instala manualmente"
        done
    fi
    echo "============================="
}