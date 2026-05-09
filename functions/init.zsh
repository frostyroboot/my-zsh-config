# functions/init.zsh
# Carga todas las funciones personalizadas

# Carga todas las funciones personalizadas

set +e

for file in "$ZSH_CONFIG/functions"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source "$file"
done

true