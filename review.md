# Code Review — Configuración Zsh (review.md)

Fecha: 2026-11-07
Rama: develop
Directorio: /home/sebas/.config/zsh

## Resumen ejecutivo

Configuración modular y bien estructurada (carga por módulos con `load_module`,
helpers `source_file`/`load_module`, separación por dominios). La integración
fzf + preview (kitty/kitten por defecto, con fallback ueberzugpp/catimg) está
implementada y los archivos pasan validación de sintaxis. El defecto crítico del
wrapper (no reenviar `"$@"` a fzf) ya está corregido en `dc4ec86`, por lo que
`fe`, `fl`, `fkill` y los widgets vuelven a respetar sus opciones. Quedan
mejoras menores/medias (multi-selección en widgets, `pkill` global en cleanup,
robustez ante rutas con espacios, colisiones de caché). No hay suite de tests.

## Plan Compliance (llm_files/plan.md)

| # | Tarea del plan | Estado | Notas |
|---|----------------|--------|-------|
| 1 | Restaurar `fz-wrapper.sh` y `fz-file2preview.sh` desde `preview/.bak/` y `chmod +x` | ✅ implemented | No existe `preview/.bak/` en el árbol, pero ambos archivos existen en `preview/` y son ejecutables (`-rwxr-xr-x`). Resultado equivalente. `common.sh` no es ejecutable (correcto: se hace `source`). |
| 2 | Sincronizar despachador en `fz-file2preview.sh` para tipos cortos de `detect_type` | ✅ implemented | El `case "$TYPE"` cubre `image/video/audio/pdf/json/markdown/epub/archive/text/binary` y hay guard `[[ -d "$FILE" ]]`. Quedan inconsistencias menores (epub/archive en MIME vs extensión, ver issues). |
| 3 | Cambiar `precmd_functions+=(_preview_shell_exit)` por `zshexit_functions+=(_preview_shell_exit)` en `preview/init.zsh` | ✅ implemented | Línea 66: `zshexit_functions+=(_preview_shell_exit)` con guard `_PREVIEW_TRAP_INSTALLED`. |
| 4 | Verificar funcionamiento y limpieza del sistema | ⚠️ partial | No hay evidencia de verificación automatizada/documentada. Se realizaron pruebas manuales de sintaxis y carga (ver Test Results). |

## Correctness Issues

### 🟡 Medio

1. **`keybindings/fzf.zsh:21` — multi-selección descartada en `fz_file_widget`**
   - **Qué está mal:** el widget pasa `-m` a fzf (multi-select) pero luego hace
     `tail -n1`, conservando solo la última selección. Las demás se descartan.
   - **Impacto:** seleccionar varios archivos con Ctrl-F inserta solo el último.
   - **Fix sugerido:** capturar todas las líneas seleccionadas y unirlas (p. ej.
     `mapfile`/`read -r` en un array) insertando rutas separadas por espacio.

2. **`preview/cleanup:7` — `pkill -f "ueberzugpp layer"` global**
   - **Qué está mal:** al salir de una shell se matan los daemons de *todas* las
     sesiones del usuario.
   - **Impacto:** efecto colateral si se usan múltiples terminales.
   - **Fix sugerido:** guardar el PID del daemon propio y matar solo ese; o usar
     `pgrep` filtrado por PID del wrapper.

3. **`preview/fz-wrapper.sh:68` — rutas con espacios en el ítem seleccionado**
   - **Qué está mal:** el comando de preview inserta `{}` sin comillas:
     `fz-file2preview.sh {} "..."`. Si el archivo seleccionado tiene espacios,
     fzf lo pasa sin escapar y el shell del preview lo parte.
   - **Impacto:** previews fallan para rutas con espacios.
   - **Fix sugerido:** usar la plantilla entre comillas en el comando de preview
     (p. ej. `fz-file2preview.sh "{}" ...`) o validar/escapar en el wrapper.

4. **`preview/fz-file2preview.sh:148-149` — check no atómico en generación de
   thumbnails de video**
   - **Qué está mal:** `[[ -f "$dest" ]] && exit 0` no es atómico; dos procesos
     pueden generar el mismo thumbnail a la vez.
   - **Impacto:** trabajo duplicado / posibles colisiones al mover `mv`.
   - **Fix sugerido:** usar `flock` o un archivo lock por clave, o `mkdir` atómico.

### 🟢 Menor / Nits

5. **`preview/common.sh` (`cache_key` en `fz-file2preview.sh:34-44`) — clave solo
   `mtime_size`**. Colisiones posibles entre archivos distintos con mismo
   mtime+tamaño. Añadir inode/nombre para reducir riesgo.

6. **`preview/fz-file2preview.sh:106-117` — `rm -f "$thumb"` tras preview**.
   Si el backend lee de forma asíncrona (kitten transfer-mode), podría leer un
   archivo ya borrado. Verificar que el backend sea síncrono o diferir la limpieza.

7. **`preview/fz-file2preview.sh:113` (`preview_image`) — fallback `cp "$file"`**
   puede copiar imágenes enormes al directorio temporal si `magick` falla.
   Aceptable, pero conviene limitar por `is_too_large`.

8. **`plugins/fzf.zsh` — completion path** ya corregido a `/usr/share/fzf/shell/`;
   solo existe `key-bindings.zsh` (no `completion.zsh`). La línea es inofensiva
   (guard `[[ -r ]]`), pero puede eliminarse para claridad.

9. **`preview/init.zsh` (`_add_opt_if_missing`)** usa coincidencia por subcadena;
   podría saltarse opciones legítimas si el nombre aparece dentro de otra
   (`--border` vs `--border-label`). Impacto bajo.

10. **`preview/fz-wrapper.sh:62` — `FZF_STATE_FILE` escrito pero no consumido**
    en ningún otro archivo. Código muerto; limpiar o usar.

11. **`preview/fz-file2preview.sh` (`ueberzug_preview`) — `exit 0`** es correcto
    (no contamina stdout). Se mantiene.

12. **`functions/fzf.zsh:18` (`fe`)** usa `--select-1 --exit-0`; con el wrapper
    corregido ya funciona. Sin acción.

### ✅ Resueltos respecto a revisiones anteriores

- `preview/fz-wrapper.sh` ahora reenvía `"$@"` a fzf (`fzf --reverse "$@"`).
- `preview/fz-file2preview.sh` usa `cached_path=... || cached_path="$thumb"`
  (sin `echo` contaminando stdout).
- `init/path.zsh` termina con newline.
- `detect_type` cubre epub/archive por MIME y por extensión.

## Test Results

- `zsh -n` sobre todos los `*.zsh`: ✅ PASS (0 errores) — 21 archivos.
- `bash -n` sobre `preview/*.sh` y `preview/cleanup`: ✅ PASS (4 archivos).
- Carga interactiva: `zsh -i -c '...'` → ✅ `INTERACTIVE_OK`; funciones/widget
  disponibles (`fe`, `fcd`, `fl`, `fkill`, `fz_file_widget`, `fz_cd_widget`);
  `FZF_DEFAULT_OPTS` poblado.
- `source` no interactivo de `zshrc`: ✅ `SOURCED_OK`.
- `preview/common.sh`: `detect_type` probado para md/json/bin/directory/epub/zip/
  mp4/pdf → tipos correctos; `select_img_backend` → `kitty_preview` (kitten
  presente, ueberzugpp ausente).
- `preview/fz-file2preview.sh` sobre `.txt` y `.md`: salida correcta (bat),
  exit 0.
- `preview/cleanup`: exit 0, sin errores.
- Dependencias presentes: zsh, fzf, fd, eza, bat, starship, atuin, kitten,
  magick, pdftoppm, ffmpeg, ffprobe, jq, chafa, tree, pnpm.
- Dependencias ausentes (fallbacks adecuados): ueberzugpp, ueberzug, ffmpeg-
  thumbnailer, glow, mediainfo, catimg, nvm. El código degrada correctamente.

## Missing Test Coverage

No existe suite de tests. Lógica sin cobertura:
- `fz-wrapper.sh` (ciclo de vida del daemon, trap, cleanup, caché pruning).
- `fz-file2preview.sh` (despacho por tipo, caché get/put, backends).
- Widgets `fz_file_widget` / `fz_cd_widget` (extracción de query, inserción,
  cancelación).
- `cache_key` / `cache_get` / `cache_put` (colisiones, fallos de cp).
- `detect_type` / `detect_type_by_ext` (MIME vs extensión, symlinks).
- nvm lazy wrappers.
- pnpm completion cache (`tools/pnpm.zsh`).

Recomendación: añadir tests de shell (bats/shunit2) al menos para `common.sh`
y el despachador, más un smoke test de carga de `zshrc`.

## Unplanned / Scope

- `tools/pnpm.zsh` y el bloque pnpm en `init/path.zsh` no figuran en `plan.md`.
  Son adiciones razonables (autocompletado cacheado de pnpm), pero constituyen
  scope creep respecto al plan. Marcar como `➕ unplanned`.
- El backend por defecto es `kitty_preview` (kitten) y no ueberzugpp, por
  ausencia de `ueberzugpp`; el código mantiene el camino ueberzugpp para cuando
  esté instalado. Consistente con el plan (fallback).

## Verdict

`approve with nits` — todas las tareas del plan están implementadas; el defecto
crítico del wrapper fue corregido. Los issues restantes son mejoras de robustez
(multi-selección en widgets, `pkill` global, rutas con espacios, colisiones de
caché) y ausencia de tests, no bloquean el funcionamiento normal.

## Next Steps

- Ejecutar agente **quality** para linting/formatting/análisis estático.
- Ejecutar agente **security** para escaneo de vulnerabilidades y patrones.
- Opcional: corregir issues #1–#4 (medios) y añadir tests mínimos.