bindkey '^F' fzf-file-widget

# Remap fzf keybindings: Solo Ctrl+F, sin Ctrl+T/Ctrl+R
bindkey -r '^T'  # Remueve Ctrl+T (fzf por defecto)
bindkey -r '^R'  # Remueve Ctrl+R (historial fzf, usas autuin en su lugar)

# Nota: Ctrl+F queda asignado en keybindings/fzf.zsh via 'bindkey "^F" fzf-file-widget'
