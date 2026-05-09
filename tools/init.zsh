# tools/init.zsh

# tools/init.zsh

set +e

for file in "$ZSH_CONFIG/tools"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source "$file"
done

true