# ~/.zshrc
export ZSH_CONFIG="${ZSH_CONFIG:-$HOME/.config/zsh}"

if [[ -f "$ZSH_CONFIG/init.zsh" ]]; then
    source "$ZSH_CONFIG/init.zsh"
else
    echo "❌ No se encontró $ZSH_CONFIG/init.zsh" >&2
fi