# Ctrl-F: pegar archivo(s) seleccionado(s) en la línea de comando
bindkey '^F' fzf-file-widget

# Ctrl-T: cd al directorio seleccionado
bindkey -r '^T'
bindkey '^T' fzf-cd-widget

# Alt-C: liberado (Ctrl-T cubre la misma funcionalidad)
bindkey -r '\ec'