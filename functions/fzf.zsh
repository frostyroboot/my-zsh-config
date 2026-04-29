fe() {
  local file
  file=$(fzf) && ${EDITOR:-nvim} "$file"
}

ff() {
  fzf --preview '
    if file --mime {} | grep -q binary; then
      echo "Binary file"
    else
      bat --style=numbers --color=always --line-range :200 {}
    fi
  '
}

fdz() {
  local dir
  dir=$(fd -t d | fzf --preview "eza --tree --level=2 --icons {}") && cd "$dir"
}

fcd() {
  cd "$(fd -t d | fzf --preview "eza --tree --level=2 --icons {}")"
}

fl() {
  eza -la --icons | fzf --ansi --preview 'bat --color=always {}'
}