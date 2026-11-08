# my-zsh-config

Configuración modular de Zsh con fzf + preview (kitty/ueberzugpp), starship, atuin.

## Instalación (one-command)

```bash
curl -fsSL https://raw.githubusercontent.com/frostyroboot/my-zsh-config/main/install.sh | bash
```

Opciones:
```bash
curl -fsSL https://raw.githubusercontent.com/frostyroboot/my-zsh-config/main/install.sh | bash -s -- --full --yes
# --minimal | --preview | --dev | --full
# --dry-run | --no-shell
```

## Requisitos
- Linux (apt/dnf/pacman) o Termux
- curl, git (el instalador los instala si faltan)

## Actualizar
```bash
cd ~/.config/zsh && git pull
```

## Termux
- Instalación: mismo comando `curl ... | bash`.
- El instalador detecta Termux (`pkg`) y no cambia el shell automáticamente; ejecuta `chsh -s zsh` si lo deseas.
- Preview de imágenes usa `chafa`/`catimg`/genérico (sin kitten/ueberzugpp).
- Algunos LSP de Neovim (Mason) pueden requerir compilación; instala manualmente si falla.

## Pruebas
```bash
./tests/smoke.sh
```