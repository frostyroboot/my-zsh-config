# aliases/init.zsh
# Carga todos los aliases

for file in "$ZSH_CONFIG/aliases"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file" || true
done