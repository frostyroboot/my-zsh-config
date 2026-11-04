# pnpm.zsh — autocompletado de pnpm
#
# La completación se genera UNA VEZ y se cachea en ~/.cache/zsh/:
# generarla en cada arranque costaría ~100-200 ms por shell.
# Tras actualizar pnpm, borra el cache para regenerarla:
#   rm ~/.cache/zsh/pnpm-completion.zsh

_pnpm_comp_cache="$HOME/.cache/zsh/pnpm-completion.zsh"

if [[ ! -f "$_pnpm_comp_cache" ]] && command -v pnpm >/dev/null; then
    mkdir -p "${_pnpm_comp_cache:h}"
    pnpm completion zsh >| "$_pnpm_comp_cache" 2>/dev/null
fi

[[ -f "$_pnpm_comp_cache" ]] && source "$_pnpm_comp_cache"

unset _pnpm_comp_cache
