# functions/init.zsh
# Carga todas las funciones personalizadas

for file in "$ZSH_CONFIG/functions"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
done