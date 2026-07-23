# tools/init.zsh

for file in "$ZSH_CONFIG/tools"/*.zsh(N); do
    [[ "${file:t}" != "init.zsh" ]] && source_file "$file" || true
done