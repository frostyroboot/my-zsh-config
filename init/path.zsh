export PATH="$PATH:$HOME/.local/bin"
export PATH="$HOME/.opencode/bin:$PATH"

# pnpm (instalador oficial get.pnpm.io)
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac