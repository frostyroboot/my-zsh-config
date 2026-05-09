# aliases/init.zsh
# Carga todos los aliases

# Carga todos los aliases

set +e

for file in "$ZSH_CONFIG/aliases"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source "$file"
done

true