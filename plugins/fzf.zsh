# fzf shell helpers (optional): completion is autoloaded from
# /usr/share/zsh/site-functions/_fzf on Fedora.
for _fzf_helper in /usr/share/fzf/shell/key-bindings.zsh /usr/share/fzf/shell/completion.zsh; do
    [[ -r "$_fzf_helper" ]] && source "$_fzf_helper"
done
unset _fzf_helper