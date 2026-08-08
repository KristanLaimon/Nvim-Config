# 🦊 Neovim Config

```

            /\   /\
           ( ..   .. )      _  __ ____  ____
            \  Y  /        | |/ /|  _ \/ ___|
         /\_/\   /\_/\     | ' / | |_) \___ \
        (  o o     o o)    | . \ |  _ < ___) |
         \  ~   ~  /       |_|\_\|_| \_\____/
          \___^___/

```

Configuración modular, moderna e hiperrápida para Neovim en Windows, diseñada con atajos intuitivos (estilo VSCode + Vim), autocompletado en tiempo real, gestión de sesiones/workspaces, terminales dinámicas, integración con Git y soporte multilenguaje vía Mason.

---

## 🛠️ Lenguajes, LSP, Formateadores y Parsers (Mason & Treesitter)

Esta configuración viene preconfigurada para instalar y gestionar automáticamente LSPs, formateadores y resaltado de sintaxis a través de **Mason**, **Conform** y **Treesitter**.

### 🛠️ Herramientas Instaladas / Autoinstalables por Mason

| Lenguaje / Entorno | LSP Server | Formateadores (Conform) | Treesitter Parser |
|---|---|---|---|
| **Lua** | `lua_ls` | `stylua` | `lua` |
| **JSON** | `jsonls` *(SchemaStore auto)* | `prettierd` / `prettier` | `json` |
| **JavaScript / TS / React** | `ts_ls` *(LSP)* | `prettierd` / `prettier` | `javascript`, `typescript`, `tsx` |
| **HTML / CSS** | `cssls` / `html` | `prettierd` / `prettier` | `html`, `css` |
| **Svelte / Astro** | — | `prettierd` / `prettier` | `svelte`, `astro` |
| **Go** | `gopls` | `gofumpt`, `goimports` | `go`, `gomod`, `gowork`, `gosum` |
| **Markdown** | — | — | `markdown`, `markdown_inline` |
| **Config / Data** | — | — | `yaml`, `toml`, `vim`, `vimdoc` |

- **JSON Schema Validation**: Integrado automáticamente con `schemastore.nvim` para autocompletar e inspeccionar validaciones en archivos `package.json`, `tsconfig.json`, `eslintrc.json`, etc.
- **Formateado al Guardar**: Activado mediante `conform.nvim` (`timeout_ms = 1000`, `lsp_fallback = true`).

---

## 📦 Plugins Instalados

### Core & LSP
| Plugin | Función |
|---|---|
| `neovim/nvim-lspconfig` | Configuración nativa de servidores LSP |
| `williamboman/mason.nvim` | Gestor de paquetes/LSPs/Formatters |
| `williamboman/mason-lspconfig.nvim` | Conector de Mason con LSPConfig |
| `zapling/mason-conform.nvim` | Instalación automática de formateadores para Conform |
| `saghen/blink.cmp` | Motor de autocompletado ultrarrápido (sustituto moderno de nvim-cmp) |
| `rafamadriz/friendly-snippets` | Colección de snippets multilenguaje |
| `stevearc/conform.nvim` | Formateador de código asíncrono y flexible |
| `nvim-treesitter/nvim-treesitter` | Highlighting y AST parsing avanzado |
| `b0o/schemastore.nvim` | Colección de esquemas JSON en tiempo real |

### Editor & Navegación
| Plugin | Función |
|---|---|
| `workspaces` *(Custom)* | Gestor de sesiones UI y workspaces (Mezcla entre Harpoon y Telescope) |
| `ThePrimeagen/harpoon` (v2) | Marcadores rápidos y navegación entre archivos |
| `nvim-telescope/telescope.nvim` | Buscador difuso (Fuzzy Finder) |
| `nvim-tree/neo-tree.nvim` | Explorador de archivos en panel lateral |
| `NeogitOrg/neogit` | Interfaz lateral para control de versiones Git |
| `sindrets/diffview.nvim` | Visor de diffs e historial para Neogit |
| `ahmedkhalf/project.nvim` | Historial y cambiador rápido de proyectos |
| `voldikss/package-info.nvim` | Gestión de dependencias `package.json` inline |
| `nvim-lua/plenary.nvim` | Librería de utilidades Lua |

### Interfaz & Tema
| Plugin | Función |
|---|---|
| `goolord/alpha-nvim` | Pantalla/dashboard de inicio con diseño ASCII |
| `doki-theme/doki-theme-vim` | Tema visual (Rei / Doki Theme) con fondo personalizado `#1e1e1e` |
| `akinsho/bufferline.nvim` | Barra de pestañas superior elegante |
| `nvim-lualine/lualine.nvim` | Barra de estado inferior responsiva |
| `nvim-highlight-colors` | Visualizador de colores CSS en vivo (hex, rgb, hsl) |
| `nvim-window-picker` | Selector visual de ventanas al abrir archivos |
| `nvim-file-operations` | Sincronización de renombrado/movimiento de archivos |

---

## ⌨️ Atajos de Teclado (Shortcuts)

> **Leader key**: `<Space>` (Espacio)

### 📂 Workspaces (Gestión de Sesiones UI)
*Una mezcla potente entre Harpoon y el selector de proyectos (`Ctrl+Shift+R`)*

| Shortcut / Comando | Modo | Descripción |
|---|---|---|
| `<C-S-w>` / `<C-S-W>` | n, i, v, t | **Abrir selector de Workspaces** (UI flotante estilo Telescope) |
| `<leader>ww` | n | Abrir selector de Workspaces |
| `<leader>ws` | n | Guardar estado UI actual como workspace (con nombre opcional) |
| `<leader>w1` .. `<leader>w9` | n | Cargar workspace del slot 1 al 9 directamente |
| `:WorkspaceSave [nombre]` | Cmd | Guardar workspace con un nombre específico |
| `:WorkspaceLoad [nombre/num]` | Cmd | Cargar un workspace por nombre o número de slot |
| `:WorkspaceDelete [nombre]` | Cmd | Eliminar un workspace guardado |
| `:WorkspaceRename [viejo] [nuevo]` | Cmd | Renombrar un workspace |
| `:Workspaces` / `:WorkspaceSelect` | Cmd | Abrir menú de selección de workspaces |

> **Dentro del menú de Workspaces (`<C-S-w>`)**:
> - `<Enter>`: Cargar workspace.
> - `a` / `<C-a>`: Guardar sesión actual como un **nuevo** workspace.
> - `s` / `<C-s>`: **Sobrescribir** el workspace seleccionado con la sesión actual.
> - `d` / `<C-d>` / `<Supr>`: **Eliminar** workspace.
> - `r` / `<C-r>` / `<F2>`: **Renombrar** workspace.
> - `g` / `<C-g>`: Alternar entre filtro del proyecto actual vs todos los proyectos.
> - `1` a `9`: Cargar slot directamente (estilo Harpoon).

---

### 💻 General & Edición de Archivos

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-s>` | n, v, i | Guardar archivo actual (`:w`) |
| `<leader>f` | n, v | Formatear archivo o selección (LSP / Conform) |
| `<F2>` | n | Renombrar archivo en disco (o elemento dentro de Neo-tree) |
| `<C-w>` | n | Cerrar buffer actual (estilo cierre de pestañas en VSCode) |
| `<C-_>` | n, v | Comentar línea (`gcc`) o selección (`gc`) |
| `<C-c>` | v | Copiar selección al portapapeles del sistema (`"+y`) |
| `<leader>i` | n | Ver imagen actual como pixel art flotante (`chafa`) |
| `<leader>cd` | n | Abrir explorador de directorio por defecto (`netrw Ex`) |
| `:ReloadConfig` | Cmd | Recargar toda la configuración de Neovim al instante |

---

### 🪟 Ventanas y Navegación

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-h>` | n | Mover cursor a la ventana izquierda |
| `<C-l>` | n | Mover cursor a la ventana derecha |
| `<C-j>` | n | Mover cursor a la ventana de abajo |
| `<C-S-k>` | n | Mover cursor a la ventana de arriba |
| `<C-Right>` | n | Hacer ventana más angosta (vertical -2) |
| `<C-Left>` | n | Hacer ventana más ancha (vertical +2) |
| `<C-Up>` | n | Hacer ventana más alta (horizontal +2) |
| `<C-Down>` | n | Hacer ventana más baja (horizontal -2) |

---

### 🩺 Diagnósticos y LSP

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>k` | n | Ver información del diagnóstico/error flotante bajo cursor |
| `<leader>u` | n | Ir al diagnóstico anterior |
| `<leader>o` | n | Ir al siguiente diagnóstico |

---

### 💻 Terminal Integrada (Múltiples terminales 1-9)

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>t` / `<leader>t1` | n | Toggle Terminal #1 (panel inferior) |
| `<leader>t2` .. `<leader>t9` | n | Toggle Terminal #2 al #9 |
| `<C-;>` | n, t | Toggle Terminal #1 desde cualquier modo |
| `<C-w>c` | n (en terminal) | Cerrar ventana de terminal activa (mata el proceso sin error) |
| `<C-w>` | t | Navegación de ventanas estándar desde modo terminal |

---

### 📌 Harpoon (v2)

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>ha` | n | Añadir archivo actual a Harpoon |
| `<leader>hh` | n | Abrir menú flotante rápido de Harpoon |
| `<leader>1` / `<leader>2` / `<leader>3` | n | Saltar a archivo en slot 1, 2 o 3 |
| `<leader>hd` | n | Eliminar archivo actual de la lista Harpoon |
| `<leader>hm` | n | Mover archivo actual un slot hacia arriba |
| `<leader>fl` | n | Ver lista de Harpoon con vista previa en Telescope |
| `<C-S-P>` | n | Saltar al item anterior de Harpoon |
| `<C-S-N>` | n | Saltar al siguiente item de Harpoon |

---

### 🔍 Telescope (Buscador Difuso & Proyectos)

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-k>` | n, i | Buscar archivos en el proyecto (`find_files`) |
| `<C-f>` | n, i | Búsqueda global de texto en tiempo real (`live_grep`) |
| `<C-S-r>` | n | Abrir lista de proyectos recientes (`projects`) |
| `<leader>fh` | n | Buscar etiquetas de ayuda (`help_tags`) |

> **Dentro de Proyectos Recientes (`<C-S-r>`)**:
> - `<C-r>` (en modo normal e insert): Eliminar proyecto seleccionado del historial.

---

### 🌴 Neo-tree (Explorador de Archivos)

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-S-Space>` / `:Neotree toggle` | n | Toggle panel lateral del explorador |
| `a` | Neo-tree | Crear nuevo archivo o directorio (con `/` al final) |
| `d` | Neo-tree | Eliminar archivo/carpeta |
| `r` | Neo-tree | Renombrar elemento |
| `c` | Neo-tree | Copiar elemento |
| `m` | Neo-tree | Mover elemento |

---

### 🌿 Neogit & Diffview (Control de Versiones)

| Shortcut | Modo | Acción |
|---|---|---|
| `<C-S-g>` | n | Toggle panel lateral de Git (status, staged/unstaged, commits) |
| `<Enter>` | Neogit Status | Abrir diff en VSplit |
| `d` | Neogit Status | Ver vista previa rápida de cambios |

---

### 📑 Bufferline (Pestañas de Buffers)

| Shortcut | Modo | Acción |
|---|---|---|
| `gt` / `<A-l>` / `<A-Right>` | n | Ir al siguiente buffer |
| `gT` / `<A-h>` / `<A-Left>` | n | Ir al buffer anterior |
| `<C-A-Left>` | n | Mover pestaña actual a la izquierda |
| `<C-A-Right>` | n | Mover pestaña actual a la derecha |

---

### 📦 package-info (npm / pnpm / bun dependencias)

| Shortcut | Modo | Acción |
|---|---|---|
| `<leader>ns` | n | Mostrar versiones de paquetes inline en `package.json` |
| `<leader>nc` | n | Ocultar versiones inline |
| `<leader>nu` | n | Actualizar paquete bajo el cursor |
| `<leader>nd` | n | Borrar paquete bajo el cursor |
| `<leader>ni` | n | Instalar paquete nuevo |
| `<leader>np` | n | Cambiar versión del paquete |

---

### ⚡ Autocompletado (Blink.cmp)

| Shortcut | Modo | Acción |
|---|---|---|
| `<CR>` | Insert | Aceptar sugerencia destacada |
| `<C-space>` / `<C-@>` | Insert | Mostrar menú de sugerencias / documentación |
