# plugins/init.zsh
# Plugins externos (puedes cargar con lazy loading más adelante)

for file in "$ZSH_CONFIG/plugins"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
done