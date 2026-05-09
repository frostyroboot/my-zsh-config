# keybindings/init.zsh

for file in "$ZSH_CONFIG/keybindings"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file"
done