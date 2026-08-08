# nvim config

```

            /\   /\
           ( ..   .. )      _  __ ____  ____
            \  Y  /        | |/ /|  _ \/ ___|
         /\_/\   /\_/\     | ' / | |_) \___ \
        (  o o     o o)    | . \ |  _ < ___) |
         \  ~   ~  /       |_|\_\|_| \_\____/
          \___^___/

```

## Plugins

### Core

| Plugin | Función |
|---|---|
| `nvim-treesitter` | Highlighting/parsing |
| `nvim-lspconfig` + `mason.nvim` + `mason-lspconfig.nvim` | LSP |
| `blink.cmp` + `friendly-snippets` | Autocompletado |
| `telescope.nvim` | Fuzzy finder |
| `neo-tree.nvim` | Explorador de archivos (sidebar) |
| `harpoon` (branch harpoon2) | Navegación rápida entre archivos |
| `neogit` | Git sidebar (staged/unstaged/log) |
| `bufferline.nvim` | Pestañas de buffers |
| `lualine.nvim` | Statusline |

### Opcionales

| Plugin | Función |
|---|---|
| `alpha-nvim` | Dashboard de inicio |
| `doki-theme-vim` | Colorscheme |
| `nvim-highlight-colors` | Preview de colores CSS inline |
| `project.nvim` | Proyectos recientes |
| `package-info.nvim` | Manejo de dependencias npm/pnpm/bun desde `package.json` |
| `diffview.nvim` | Vista de diffs (integración de neogit) |
| `nvim-window-picker` | Selección de ventana al abrir archivo desde neo-tree |
| `nvim-file-operations` / `Crysthamus/nvim-file-operations` | Operaciones de archivo sincronizadas con neo-tree |

## Shortcuts custom

Leader = `<Space>`

### General

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>cd` | n | Abrir explorador (netrw `Ex`) |
| `<C-_>` | n, v | Comentar línea/selección |
| `<C-c>` | v | Copiar a clipboard del sistema |
| `<C-h>` / `<C-l>` / `<C-j>` / `<C-S-k>` | n | Mover entre ventanas (izq/der/abajo/arriba) |
| `<leader>k` | n | Ver diagnóstico bajo cursor |
| `<leader>u` | n | Diagnóstico anterior |
| `<leader>o` | n | Siguiente diagnóstico |
| `<leader>f` | n | Formatear archivo (LSP) |
| `<C-w>` | n | Cerrar buffer actual |
| `<C-S-w>` | n, t | Cerrar ventana actual |

### Terminal

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>t` | n, t | Toggle terminal |
| `<C-;>` | n, t | Toggle terminal |
| `<C-w>` | t | Ir a ventana (passthrough a `<C-w>` normal) |

### Neo-tree (explorador)

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>e` | n | Toggle sidebar |
| `<C-S-Space>` | n | Toggle sidebar |
| `<C-n>` | n (dentro neo-tree) | Crear archivo |
| `<C-S-n>` | n (dentro neo-tree) | Crear directorio |

### Neogit (git)

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-S-g>` | n | Toggle sidebar git (staged/unstaged/log, ancho derecho) |

### Harpoon

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>ha` | n | Añadir archivo actual |
| `<leader>hh` | n | Abrir menú harpoon |
| `<leader>1` / `<leader>2` / `<leader>3` | n | Saltar a item 1/2/3 |
| `<leader>hd` | n | Borrar item actual |
| `<leader>hm` | n | Mover item actual hacia arriba |
| `<leader>fl` | n | Lista harpoon vía telescope |
| `<C-S-P>` / `<C-S-N>` | n | Item anterior/siguiente |

### Telescope

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-k>` | n, i | Buscar archivos |
| `<C-f>` | n, i | Live grep |
| `<leader>fh` | n | Buscar help tags |
| `<C-S-r>` | n | Proyectos recientes |

### Bufferline

| Shortcut | Modo | Acción |
|---|---|---|
| `gt` | n | Siguiente buffer |
| `gT` | n | Buffer anterior |

### package-info (package.json)

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>ns` | n | Mostrar versiones inline |
| `<leader>nc` | n | Ocultar versiones inline |
| `<leader>nu` | n | Actualizar paquete bajo cursor |
| `<leader>nd` | n | Borrar paquete bajo cursor |
| `<leader>ni` | n | Instalar paquete nuevo |
| `<leader>np` | n | Cambiar versión de paquete |
