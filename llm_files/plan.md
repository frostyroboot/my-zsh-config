# Plan de Implementación: Reparación de fzf-preview y Ueberzugpp

## Tareas

- [ ] 1. Restaurar `fz-wrapper.sh` y `fz-file2preview.sh` desde `preview/.bak/` a `preview/` y darles permisos de ejecución (`chmod +x`).
- [ ] 2. Sincronizar el despachador en `preview/fz-file2preview.sh` para que maneje correctamente los tipos cortos devueltos por `detect_type` (`directory`, `image`, `video`, `audio`, `pdf`, `json`, `markdown`, `epub`, `archive`, `text`, `binary`).
- [ ] 3. Corregir `preview/init.zsh` cambiando `precmd_functions+=(_preview_shell_exit)` por `zshexit_functions+=(_preview_shell_exit)`.
- [ ] 4. Verificar el funcionamiento y limpieza del sistema.
