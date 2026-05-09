# core/init.zsh
# Configuración principal de Zsh (Oh My Zsh, prompt, opciones)

for file in "$ZSH_CONFIG/core"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
done