# ~/.config/zsh/init.zsh
# Archivo principal de configuración

export ZSH_CONFIG="${ZSH_CONFIG:-$HOME/.config/zsh}"

setopt extended_glob null_glob

# ====================== FUNCIONES DE AYUDA ======================
source_file() {
    [[ -f "$1" && -r "$1" ]] || return
    if ! source "$1" 2>/dev/null; then
        echo "❌ Error cargando: $1" >&2
    fi
}

load_module() {
    local module="$1"
    local init_file="$ZSH_CONFIG/$module/init.zsh"
    
    if [[ -f "$init_file" ]]; then
        source_file "$init_file"
    else
        # Fallback: cargar directamente los archivos .zsh
        for file in "$ZSH_CONFIG/$module"/*.zsh(N); do
            [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
        done
    fi
}

# ====================== ORDEN DE CARGA ======================
load_module "init"          # Variables de entorno y PATH (primero)
load_module "core"          # Configuración base de Zsh
load_module "plugins"       # Plugins externos
load_module "functions"     # Funciones personalizadas
load_module "aliases"       # Aliases
load_module "keybindings"   # Atajos de teclado
load_module "tools"         # Herramientas y scripts