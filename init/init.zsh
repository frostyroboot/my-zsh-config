# init/init.zsh
# Variables de entorno y PATH

# Cargar archivos de este módulo
for file in "$ZSH_CONFIG/init"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
done