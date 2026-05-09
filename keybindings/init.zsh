# keybindings/init.zsh

# keybindings/init.zsh

set +e

for file in "$ZSH_CONFIG/keybindings"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source "$file"
done

true