export ZSH="$HOME/.oh-my-zsh"

if [[ ! -f "$ZSH/oh-my-zsh.sh" ]]; then
    echo "⚠️  Oh My Zsh no encontrado en $ZSH — saltando carga" >&2
else
    plugins=(git zsh-syntax-highlighting)
    source "$ZSH/oh-my-zsh.sh"
fi