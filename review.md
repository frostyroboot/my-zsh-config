# Code Review — Configuración Zsh (review.md)

Fecha: 2026-11-04
Rama: develop
Directorio: /home/sebas/.config/zsh

## Resumen ejecutivo

La configuración es modular y bien estructurada (carga por módulos con `load_module`,
helpers `source_file`/`load_module`, separación `init/plugins/preview/core/functions/
aliases/keybindings/tools`). La integración de fzf + preview (ueberzugpp/kitty) está
mayormente implementada y los archivos pasan validación de sintaxis. Se detectó un
defecto funcional relevante en el orquestador `fz-wrapper.sh` que ignora los
argumentos pasados por sus callers, degradando `fe`, `fl`, `fkill` y los widgets
de teclado. El resto son mejoras menores / portabilidad Fedora.

## Plan Compliance (llm_files/plan.md)

| # | Tarea del plan | Estado | Notas |
|---|----------------|--------|-------|
| 1 | Restaurar `fz-wrapper.sh` y `fz-file2preview.sh` desde `preview/.bak/` y `chmod +x` | ✅ implemented | No existe `preview/.bak/` en el árbol actual, pero ambos archivos existen en `preview/` y son ejecutables (`-rwxr-xr-x`). Resultado equivalente. |
| 2 | Sincronizar despachador en `fz-file2preview.sh` para tipos cortos de `detect_type` | ✅ implemented | `case "$TYPE"` cubre `image/video/audio/pdf/json/markdown/epub/archive/text/binary` y hay guard `[[ -d "$FILE" ]]`. Quedan inconsistencias menores (ver issues). |
| 3 | Cambiar `precmd_functions+=(_preview_shell_exit)` por `zshexit_functions+=(_preview_shell_exit)` en `preview/init.zsh` | ✅ implemented | Línea 66: `zshexit_functions+=(_preview_shell_exit)` con guard `_PREVIEW_TRAP_INSTALLED`. |
| 4 | Verificar funcionamiento y limpieza del sistema | ⚠️ partial | No hay evidencia de verificación automatizada/documentada. Se realizaron pruebas manuales de sintaxis y carga (ver Test Results). |

## Correctness Issues

### 🔴 Crítico

1. **`preview/fz-wrapper.sh:67-70` — fzf no reenvía `"$@"`**
   - **Qué está mal:** la invocación final de fzf es fija:
     `fzf --reverse --preview "..." --bind ... --bind ...`
     y **no incluye `"$@"`**. Todos los argumentos que los callers pasan (fe, fl,
     fkill, widgets) son silenciosamente descartados.
   - **Impacto:** `fe` ignora `--select-1 --exit-0` (no auto-selecciona ni sale
     sin coincidencias); `fl` ignora `--ansi` (los colores de eza se muestran
     como secuencias de escape); `fkill` ignora `--header`; los widgets ignoran
     `--query`, `--select-1`, `--exit-0`, `-m`.
   - **Esperado (plan/código):** el wrapper debe actuar como orquestador y pasar
     las opciones adicionales a fzf.
   - **Fix sugerido:** `fzf --reverse "$@" --preview "$PREVIEW_DIR/..." ...`

### 🟡 Medio

2. **`plugins/fzf.zsh:1` — ruta de completion inexistente en Fedora**
   - **Qué está mal:** `source /usr/share/fzf/completion.zsh` no existe en este
     sistema (los archivos de fzf están en `/usr/share/fzf/shell/` y no hay
     `completion.zsh`).
   - **Impacto:** la línea falla silenciosamente por el `&&`; sin autocompletado
     del comando `fzf`. No rompe la carga.
   - **Fix sugerido:** usar `/usr/share/fzf/shell/key-bindings.zsh` si se quiere
     keybindings de fzf, o eliminar la línea (los widgets son propios).

3. **`preview/fz-file2preview.sh:325-332` — despachador inconsistente con `detect_type`**
   - **Qué está mal:** el fallback por extensión maneja `*.epub` y archivos
     comprimidos, pero `detect_type`/`detect_type_by_ext` (common.sh) nunca
     devuelve `"epub"` ni `"archive"` para todos los casos (p. ej. epub no está
     en la lista de extensiones; octet-stream cae en `detect_type_by_ext` que
     no lista epub). El caso `"archive"` del despachador depende de que
     `detect_type` devuelva `"archive"`, lo cual solo ocurre para MIME conocidos.
   - **Impacto:** epubs se tratan como binarios (fallback `file`) en la práctica.
   - **Fix sugerido:** añadir `*.epub` y las extensiones de archivo a
     `detect_type_by_ext` en `common.sh`.

4. **`preview/fz-file2preview.sh:113-116` — manejo de fallo de `cache_put`**
   - **Qué está mal:** `cached_path=$(cache_put ...) || echo "$thumb"` hace que,
     si `cache_put` falla, el `echo` imprima la ruta al stdout (contaminando
     el preview) y `cached_path` quede vacío, invocando `$IMG_PREVIEW ""`.
   - **Fix sugerido:** `cached_path=$(cache_put ...) || cached_path="$thumb"`.

5. **`preview/cleanup:7` — `pkill -f "ueberzugpp layer"` global**
   - **Qué está mal:** al salir de una shell se matan los daemons de *todas* las
     shells/sesiones del usuario.
   - **Impacto:** efecto colateral si se usan múltiples terminales.
   - **Fix sugerido:** guardar el PID del daemon propio y matar solo ese.

6. **`functions/fzf.zsh:29` — `fl()` pasa `--ansi` que se descarta (consecuencia de #1)**
   - Se resuelve con el fix #1.

### 🟢 Menor / Nits

7. **`init/path.zsh:9` — sin newline final** (minor, estilo).

8. **`preview/common.sh:27-30` — markdown solo si MIME es `text/markdown`**.
   La mayoría de `.md` se detecta como `text/plain` → `text`, así que se usan
   con `bat` en lugar de `glow`. Funcional, pero `preview_markdown` rara vez se
   invoca. Mejora opcional.

9. **`preview/fz-file2preview.sh:65` — `exit 1` en `ueberzug_preview`**.
   Con backend kitty (el seleccionado aquí) no se usa; con ueberzug, un exit
   code 1 puede ser interpretado por fzf como fallo del comando de preview.
   Considerar `return 0` tras escribir al FIFO.

10. **`preview/fz-file2preview.sh:149` — race en generación de thumbnails de video**:
    comprobación `[[ -f "$dest" ]]` no atómica; dos procesos pueden generar a la
    vez. Impacto bajo.

11. **`preview/fz-file2preview.sh:19-28` — clave de caché solo `mtime_size`**:
    colisiones entre archivos distintos con mismo mtime+tamaño. Impacto bajo.

12. **`keybindings/fzf.zsh:21` — limpieza de escape sequences** con `sed` puede no
    cubrir todos los casos (APC/kitty). Funciona en la práctica; mantener.

13. **`core/ohmyzsh.zsh:6` — `plugins=(git zsh-syntax-highlighting)`** requiere
    el plugin OMZ instalado (presente). Verificado OK.

## Test Results

- `zsh -n` sobre todos los `*.zsh`: ✅ PASS (0 errores) — 21 archivos.
- `bash -n` sobre `preview/*.sh` y `preview/cleanup`: ✅ PASS.
- Carga interactiva: `zsh -i -c '...'` → ✅ `INTERACTIVE_OK`, widgets y
  funciones disponibles (`fe`, `fz_file_widget`), `FZF_DEFAULT_OPTS` poblado.
- `source` no interactivo de `zshrc`: ✅ `SOURCED_OK`.
- `preview/common.sh`: `detect_type`, `is_too_large`, `select_img_backend`
  (devuelve `kitty_preview`) → ✅.
- `preview/fz-file2preview.sh` sobre un `.md`: produce salida (bat) → ✅ (exit 0
  con stdout redirigido; exit 1 observado en terminal por bat/color, sin impacto).
- Dependencias presentes: kitten, magick, pdftoppm, ffmpeg, jq, chafa, fzf, fd,
  eza, bat. Ausentes: ueberzugpp, ffmpegthumbnailer, glow, mediainfo, epub-thumbnailer
  (el código hace fallback adecuado).

## Missing Test Coverage

No existe suite de tests. Lógica sin cobertura:
- `fz-wrapper.sh` (ciclo de vida del daemon, trap, cleanup).
- `fz-file2preview.sh` (despacho por tipo, caché, backends).
- Widgets `fz_file_widget` / `fz_cd_widget` (extracción de query, inserción).
- `cache_key` / `cache_get` / `cache_put`.
- nvm lazy wrappers.
- pnpm completion cache.

Recomendación: añadir tests de shell (bats) al menos para `common.sh` y el
despachador, y un smoke test de carga de `zshrc`.

## Unplanned / Scope

- `tools/pnpm.zsh` (untracked) y el bloque pnpm añadido a `init/path.zsh`
  (untracked) no figuran en `plan.md`. Son adiciones razonables (autocompletado
  cacheado de pnpm), pero constituyen scope creep respecto al plan. Marcar como
  `➕ unplanned`.

## Verdict

`request changes` — por el defecto crítico #1 (el wrapper no reenvía `"$@"`),
que rompe funcionalidad documentada (`fe`, `fl`, `fkill`, widgets). El resto de
la configuración es sólida y pasa validación de sintaxis/carga.

## Next Steps

- Ejecutar agente **quality** para linting/formatting/análisis estático.
- Ejecutar agente **security** para escaneo de vulnerabilidades y patrones.
- Corregir issue #1 y, opcionalmente, #2–#5.