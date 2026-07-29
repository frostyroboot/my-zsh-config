# preview/ - Sistema de preview de fzf

## Resumen

Integración de fzf con preview de imágenes/videos/PDFs/archivos basada en la
**arquitectura de [gmou3/fzf-preview](https://github.com/gmou3/fzf-preview)**.

**Patrón clave:** un único proceso persistente de ueberzugpp que vive durante
toda la sesión de fzf. El wrapper (`fz-wrapper.sh`) orquesta el ciclo de vida
del daemon y los previews escriben comandos JSON al FIFO.

## Estructura

```
preview/
├── init.zsh               # integración zsh: configura FZF_DEFAULT_OPTS + cleanup
├── fz-wrapper.sh          # ORQUESTADOR: lanza daemon + ejecuta fzf + cleanup
├── fz-file2preview.sh     # HANDLER: detecta tipo + genera thumbnail + dibuja
├── cleanup                # helper: mata daemons huérfanos al logout
├── common.sh               # utilidades: detección de tipo, stat portable
└── README.md              # este archivo
```

6 archivos. ~500 líneas de código.

## Cómo funciona

```
Usuario presiona Ctrl-F
    ↓
fz_file_widget (zle widget)
    ↓
fz-wrapper.sh (orquestador)
    ├── Crea TMP_DIR y FIFO
    ├── Lanza daemon: tail -f --pid=$$ $FIFO | ueberzugpp layer --silent &
    │   (--pid=$$: tail muere cuando wrapper sale → pipe se rompe → daemon muere)
    ├── Ejecuta fzf (subproceso, NO exec → trap funciona)
    │   fzf --preview="$FZF_PREVIEW_DIR/fz-file2preview.sh {} 'ueberzug' ..."
    │       ↓ por cada cambio de selección
    │   fz-file2preview.sh
    │       ├── Detecta tipo (MIME)
    │       ├── Genera thumbnail si es necesario (ffmpegthumbnailer/pdftoppm/magick)
    │       ├── Escribe JSON al FIFO: {"action":"add","identifier":"fzf",...}
    │       └── daemon de ueberzugpp lo lee y dibuja
    ├── Usuario sale de fzf
    └── trap EXIT → cleanup: remove image, mata daemon, rm TMP_DIR
```

## Patrón `tail -f --pid=$$` (la clave de la solución)

```bash
tail -f --pid=$$ "$FIFO" 2>/dev/null | ueberzugpp layer --silent &
```

Este one-liner resuelve todos los problemas de lifecycle:
- `tail -f` mantiene el FIFO abierto para lectura (no necesita `exec 3>`)
- `--pid=$$` mata `tail` cuando el wrapper termina → pipe se rompe → ueberzugpp recibe EOF/SIGPIPE → muere solo
- Sin `setsid`, sin `disown`, sin `kill` manual
- Sin race conditions, sin daemons huérfanos

## Tipos de archivo soportados

| Tipo | Herramienta | Notas |
|------|-------------|-------|
| Directorio | `eza --tree` | Con iconos |
| Imagen | `ueberzugpp` (nativo) / `chafa` (fallback) | Auto-orient, thumbnail cacheado |
| Video | `ffmpegthumbnailer` / `ffmpeg` | Primer fotograma cacheado |
| PDF | `pdftoppm` | Primera página cacheada |
| Audio | `ffmpeg` (cover art) | Thumbnail cacheado |
| EPUB | `epub-thumbnailer` | Portada |
| Markdown | `glow` / `bat` | Renderizado formateado |
| JSON | `jq` | Pretty-print |
| Texto/código | `bat` | Syntax highlighting |
| Comprimidos | `tar`/`unzip`/`7z` | Lista de contenido |
| Binarios | `file` | Info MIME |

## Backends de imagen (auto-detección)

1. **Kitty/Ghostty** (`$KITTY_WINDOW_ID` o `$GHOSTTY_RESOURCES_DIR`): usa `kitten icat` (nativo)
2. **ueberzugpp** (disponible): usa el daemon + FIFO
3. **chafa**: fallback a bloques Unicode con color
4. **catimg**: ASCII art (baja calidad)

## Dependencias

### Esenciales
```bash
sudo pacman -S fzf fd eza bat
```

### Recomendadas (para preview rico)
```bash
sudo pacman -S chafa ueberzugpp glow jq mediainfo \
               pdftoppm ffmpegthumbnailer imagemagick \
               p7zip
```

### Opcionales
```bash
sudo pacman -S epub-thumbnailer
```

## Configuración

| Variable | Default | Descripción |
|----------|---------|-------------|
| `FZF_PREVIEW_DIR` | `~/.config/zsh/preview` | Directorio del módulo |
| `FZF_PREVIEW_SCRIPT` | `$FZF_PREVIEW_DIR/fz-file2preview.sh` | Handler llamado por fzf |
| `FZF_PREVIEW_WRAPPER` | `$FZF_PREVIEW_DIR/fz-wrapper.sh` | Orquestador del daemon |
| `FZF_PREVIEW_MAX_FILE_SIZE` | `104857600` (100MB) | Archivos mayores no se previsualizan |
| `FZF_PREVIEW_DEBUG` | `0` | `1` para logs de debug |

## Keybindings

| Keybinding | Acción |
|------------|--------|
| `Ctrl-F` | Seleccionar archivo (custom widget) |
| `Ctrl-T` | Seleccionar directorio (custom widget) |
| `Alt-C` | Liberado (Ctrl-T cubre esto) |
| `Ctrl-R` | Historial (atuin) |

## Cache de thumbnails

- **Ubicación:** `~/.cache/fzf-preview/`
- **Clave:** `mtime_size` (se regeneran automáticamente si el archivo cambia)
- **Límite:** 200 archivos más recientes (los antiguos se eliminan al logout)

## Cómo probarlo

```bash
# Cargar config
source ~/.zshrc

# Verificar que el daemon arranca
ls -la /tmp/fzf-preview.*/ueberzug-fifo

# Probar imagen
fe imagen.png

# Probar video (debe mostrar el primer fotograma)
fe video.mp4

# Probar PDF (debe mostrar la primera página)
fe documento.pdf

# Probar directorio
Ctrl-T

# Verificar que no quedan daemons al cerrar
pgrep -af "ueberzugpp layer"
# Debe estar vacío
```

## Rollback

```bash
# Si algo falla, el rollback es:
rm -rf /home/sbtnmf/.config/zsh/preview/
git checkout init.zsh plugins/fzf.zsh functions/fzf.zsh keybindings/fzf.zsh
```

## Referencias

- **[gmou3/fzf-preview](https://github.com/gmou3/fzf-preview)** - Proyecto base cuya arquitectura adoptamos
- [Yazi - yazi-adapter/src/drivers/ueberzug.rs](https://github.com/sxyazi/yazi) - Referencia de patrón IPC
- [ranger - img_display.py (UeberzugImageDisplayer)](https://github.com/ranger/ranger) - Referencia de Popen + Timer kill
- [ueberzugpp](https://github.com/jstkdng/ueberzugpp) - Daemon de imágenes para terminal
- [chafa](https://hpjansson.org/chafa/) - Image-to-ANSI converter (fallback)
