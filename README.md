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

A modular, modern, and hyper-fast Neovim configuration for Windows, Linux, and WSL, designed with intuitive keybindings (VSCode + Vim hybrid style), real-time autocompletion, session/workspace management, dynamic terminals, Git integration, and multi-language support via Mason.

---

## ⚙️ System Requirements & External Dependencies

To get full functionality (fast fuzzy finding, desktop folder browsing, image previews, LSP auto-installation, Treesitter compiling, and Git integration), install the required CLI tools using **Scoop** on Windows (or your Linux package manager):

### 🚀 Quick Scoop Installation (Windows)
```powershell
scoop bucket add main
scoop bucket add extras
scoop install neovim git ripgrep fd chafa gcc nodejs-lts go
```

### 📋 System Dependencies Breakdown

| Tool / CLI | Purpose in Config | Scoop Command (Windows) | Linux / WSL Package |
|---|---|---|---|
| **Neovim** (>= 0.10) | Core Neovim editor | `scoop install neovim` | `neovim` |
| **Git** | Mason, Neogit, Lazy plugin manager | `scoop install git` | `git` |
| **ripgrep** (`rg`) | Telescope live grep text search (`<C-f>`) | `scoop install ripgrep` | `ripgrep` |
| **fd** | Telescope Desktop folder browser (`<C-o>`) & fast file finder | `scoop install fd` | `fd-find` / `fd` |
| **chafa** | Terminal pixel-art image previewer (`<leader>i`) | `scoop install chafa` | `chafa` |
| **GCC / MinGW** | Compiling Treesitter language parsers | `scoop install gcc` | `gcc` / `build-essential` |
| **Node.js & npm** | JS/TS LSP (`ts_ls`), JSON, HTML/CSS LSPs & Prettier | `scoop install nodejs-lts` | `nodejs` `npm` |
| **Go** | Go LSP (`gopls`), `gofumpt`, `goimports` | `scoop install go` | `golang` |

---

## 🛠️ Languages, LSP, Formatters & Parsers (Mason & Treesitter)

This configuration comes preconfigured to automatically install and manage LSPs, formatters, and syntax highlighting via **Mason**, **Conform**, and **Treesitter**.

### 🛠️ Pre-configured Tools Managed by Mason

| Language / Environment | LSP Server | Formatters (Conform) | Treesitter Parser |
|---|---|---|---|
| **Lua** | `lua_ls` | `stylua` | `lua` |
| **JSON** | `jsonls` *(SchemaStore auto)* | `prettierd` / `prettier` | `json` |
| **JavaScript / TS / React** | `ts_ls` *(LSP)* | `prettierd` / `prettier` | `javascript`, `typescript`, `tsx` |
| **HTML / CSS** | `cssls` / `html` | `prettierd` / `prettier` | `html`, `css` |
| **Svelte / Astro** | — | `prettierd` / `prettier` | `svelte`, `astro` |
| **Go** | `gopls` | `gofumpt`, `goimports` | `go`, `gomod`, `gowork`, `gosum` |
| **Markdown** | — | — | `markdown`, `markdown_inline` |
| **Config / Data** | — | — | `yaml`, `toml`, `vim`, `vimdoc` |

- **JSON Schema Validation**: Automatically integrated with `schemastore.nvim` for autocompletion and live validation in `package.json`, `tsconfig.json`, `eslintrc.json`, etc.
- **Format on Save**: Enabled via `conform.nvim` (`timeout_ms = 1000`, `lsp_fallback = true`).

---

## 📦 Installed Plugins & Custom Modules

### 🛠️ Custom-Tailored Plugins & Modules
| Feature / Custom Plugin | Location | Purpose & Key Features | Keybindings |
|---|---|---|---|
| **Workspaces Manager** | [`lua/plugins/editor/workspaces.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/workspaces.lua) | UI session & workspace manager (Harpoon + Telescope hybrid). Persists open buffers, tab layouts, and `cwd` per project with slot shortcuts, rename/overwrite capabilities, and Telescope floating UI. | `<C-S-w>`, `<leader>ws`, `<leader>ww`, `<leader>wm`, `<leader>w1`..`9`, `<C-m>` |
| **Desktop Folder Browser** | [`lua/plugins/editor/telescope.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/telescope.lua) | Custom Telescope folder picker starting at `~/Desktop`. Allows folder selection, changes `cwd`, opens Neo-tree, and registers folders into recent project history (`<C-S-r>`). Supports drill-down (`<C-l>`) and parent nav (`<C-h>`). | `<C-S-o>` (n, i) |
| **Multi-Terminal Manager** | [`lua/config/keybinds.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/keybinds.lua) | 1-9 indexed toggleable terminal system. Opens bottom split terminals, auto-hides when leaving window focus, and manages tab list cleanliness. | `<C-;>`, `<leader>t1`..`9` |
| **Live Colorscheme Previewer** | [`lua/config/keybinds.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/keybinds.lua) | Real-time command-line previewer for `:colorscheme`. Previews colors as you tab through choices and restores previous theme if cancelled (`<Esc>`). | `:colorscheme <Tab>` |
| **Pixel Art Image Viewer** | [`lua/config/keybinds.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/keybinds.lua) | Floating terminal window image viewer powered by `chafa` to render pixel art previews of images within Neovim. | `<leader>i` |

### Core & LSP
| Plugin | Purpose |
|---|---|
| `neovim/nvim-lspconfig` | Native LSP server configuration |
| `williamboman/mason.nvim` | Package manager for LSPs, formatters & linters |
| `williamboman/mason-lspconfig.nvim` | Mason integration with nvim-lspconfig |
| `zapling/mason-conform.nvim` | Automatic installer for Conform formatters |
| `saghen/blink.cmp` | Blazing-fast completion engine (modern nvim-cmp replacement) |
| `rafamadriz/friendly-snippets` | Multi-language snippet collection |
| `stevearc/conform.nvim` | Fast asynchronous code formatter |
| `nvim-treesitter/nvim-treesitter` | Advanced code highlighting and AST parsing |
| `b0o/schemastore.nvim` | Real-time JSON schemas for popular files |

### Editor & Navigation
| Plugin | Purpose |
|---|---|
| `ThePrimeagen/harpoon` (v2) | Fast file bookmarking and navigation |
| `nvim-telescope/telescope.nvim` | Powerful Fuzzy Finder |
| `nvim-tree/neo-tree.nvim` | Sidebar file explorer |
| `NeogitOrg/neogit` | Git interface sidebar |
| `sindrets/diffview.nvim` | Diff viewer and history tool for Neogit |
| `ahmedkhalf/project.nvim` | Project history and quick switching |
| `voldikss/package-info.nvim` | Inline `package.json` dependency management |
| `nvim-lua/plenary.nvim` | Lua utility library |

### Interface & Theme
| Plugin | Purpose |
|---|---|
| `goolord/alpha-nvim` | ASCII start dashboard |
| `doki-theme/doki-theme-vim` | Visual theme (Rei / Doki Theme) with custom `#1e1e1e` background |
| `akinsho/bufferline.nvim` | Sleek top buffer tab bar |
| `nvim-lualine/lualine.nvim` | Responsive statusline |
| `nvim-highlight-colors` | Live inline CSS color preview (hex, rgb, hsl) |
| `nvim-window-picker` | Visual window selector when opening files |
| `nvim-file-operations` | Automatic file rename and move synchronization |

---

## ⌨️ Keyboard Shortcuts

> **Leader key**: `<Space>`

### 📂 Workspaces (Session & UI Management)
*A powerful hybrid between Harpoon and Project Selector (`Ctrl+Shift+R`)*

| Shortcut / Command | Mode | Description |
|---|---|---|
| `<C-S-w>` / `<C-S-W>` | n, i, v, t | **Open Workspaces picker** (Telescope floating UI) |
| `<C-m>` / `<C-S-m>` | n, i, v, t | **Close session & Return to Main Menu** (with save prompt) |
| `<leader>ww` | n | Open Workspaces picker |
| `<leader>ws` | n | Save current UI state as a workspace (optional name) |
| `<leader>wm` | n | Close session & Return to Main Menu (Dashboard) |
| `<leader>w1` .. `<leader>w9` | n | Load workspace from slot 1 to 9 directly |
| `:WorkspaceSave [name]` | Cmd | Save workspace with a name |
| `:WorkspaceLoad [name/slot]` | Cmd | Load a workspace by name or slot number |
| `:WorkspaceClose` / `:WorkspaceMenu` | Cmd | Prompt to save and return to main menu (Dashboard) |
| `:WorkspaceDelete [name]` | Cmd | Delete a saved workspace |
| `:WorkspaceRename [old] [new]` | Cmd | Rename a workspace |
| `:Workspaces` / `:WorkspaceSelect` | Cmd | Open Workspaces selector UI |

> **Inside the Workspaces menu (`<C-S-w>`)**:
> - `<Enter>`: Load selected workspace.
> - `a` / `<C-a>`: Save current session as a **new** workspace.
> - `s` / `<C-s>`: **Overwrite** selected workspace with current state.
> - `d` / `<C-d>` / `<Del>`: **Delete** workspace.
> - `r` / `<C-r>` / `<F2>`: **Rename** workspace.
> - `g` / `<C-g>`: Toggle filter between current project vs all projects.
> - `1` to `9`: Jump directly to slot (Harpoon style).

---

### 💻 General & File Editing

| Shortcut | Mode | Action |
|---|---|---|
| `<C-s>` | n, v, i | Save current file (`:w`) |
| `<C-+>` / `<C-=>` | n, i, v, t | **Increase font size** (`+1pt`, saved permanently) |
| `<C-->` | n, i, v, t | **Decrease font size** (`-1pt`, saved permanently) |
| `<C-0>` | n, i, v, t | **Reset font size** to default (`14pt`) |
| `<leader>f` | n, v | Format file or selection (LSP / Conform) |
| `<F2>` | n | Rename file on disk (or item inside Neo-tree) |
| `<C-w>` | n | Close current buffer (VSCode tab close style) |
| `<C-_>` | n, v | Comment line (`gcc`) or selection (`gc`) |
| `<C-c>` | v | Copy selection to system clipboard (`"+y`) |
| `<leader>i` | n | View image as pixel art float window (`chafa`) |
| `<leader>cd` | n | Open default netrw directory browser (`netrw Ex`) |
| `:ReloadConfig` | Cmd | Reload Neovim configuration instantly |

---

### 🪟 Windows & Navigation

| Shortcut | Mode | Action |
|---|---|---|
| `<C-h>` | n | Move focus to left window |
| `<C-l>` | n | Move focus to right window |
| `<C-j>` | n | Move focus to bottom window |
| `<C-S-k>` | n | Move focus to top window |
| `<C-Right>` | n | Make window narrower (vertical -2) |
| `<C-Left>` | n | Make window wider (vertical +2) |
| `<C-Up>` | n | Make window taller (horizontal +2) |
| `<C-Down>` | n | Make window shorter (horizontal -2) |

---

### 🩺 Diagnostics & LSP

| Shortcut | Mode | Action |
|---|---|---|
| `<A-k>` / `<M-k>` | n, v | **Go to Definition** of symbol/method under cursor |
| `<C-o>` | n | **Jump Back** to previous cursor location (Vim jump list) |
| `<leader>k` | n | Show diagnostic error info floating under cursor |
| `<leader>u` | n | Jump to previous diagnostic |
| `<leader>o` | n | Jump to next diagnostic |

### 🐞 Debugging (DAP)

| Shortcut | Mode | Action |
|---|---|---|
| `<A-j>` / `<M-j>` | n, i, v | **Toggle Breakpoint** 🔴 on current line |
| `<C-S-s>` | n, i, v | **Start / Continue Debugging** 🐞 (opens DAP-UI automatically) |
| `<C-S-x>` | n, i, v | **Terminate Debugger** (closes debug session and UI) |

---

### 🛠️ Per-Project Task & Script Manager

| Shortcut | Mode | Action |
|---|---|---|
| `<C-S-a>` | n, i, v | **Run Default Project Script** (auto-detects `Makefile`/`package.json` with `cwd = project_root`) |
| `<leader>ta` | n | **Open Task Menu UI** (select, run, set default `[d]`, add `[a]`, delete `[x]`) |

---

### 💻 Integrated Terminal (Multiple Terminals 1-9)

| Shortcut | Mode | Action |
|---|---|---|
| `<leader>t` / `<leader>t1` | n | Toggle Terminal #1 (bottom panel) |
| `<leader>t2` .. `<leader>t9` | n | Toggle Terminal #2 to #9 |
| `<C-;>` | n, t | Toggle Terminal #1 from any mode |
| `<C-w>c` | n (in terminal) | Close active terminal window (kills process safely) |
| `<C-w>` | t | Standard window navigation from terminal mode |

---

### 📌 Harpoon (v2)

| Shortcut | Mode | Action |
|---|---|---|
| `<leader>ha` | n | Add current file to Harpoon |
| `<leader>hh` | n | Open Harpoon quick menu |
| `<leader>1` / `<leader>2` / `<leader>3` | n | Jump to file in slot 1, 2, or 3 |
| `<leader>hd` | n | Remove current file from Harpoon list |
| `<leader>hm` | n | Move current file up one slot |
| `<leader>fl` | n | View Harpoon list with preview in Telescope |
| `<C-S-P>` | n | Jump to previous Harpoon item |
| `<C-S-N>` | n | Jump to next Harpoon item |

---

### 🔍 Telescope (Fuzzy Finder & Projects)

| Shortcut | Mode | Action |
|---|---|---|
| `<C-k>` | n, i | Find files in project (`find_files`) |
| `<C-f>` | n, i | Live global text search (`live_grep`) |
| `<C-o>` | n, i | Open system folder browser at Desktop |
| `<C-S-r>` | n | Open recent projects list (`projects`) |
| `<leader>fh` | n | Search help tags (`help_tags`) |

> **Inside Recent Projects (`<C-S-r>`)**:
> - `<C-r>` (normal & insert mode): Remove selected project from history.

---

### 🌴 Neo-tree (File Explorer)

| Shortcut | Mode | Action |
|---|---|---|
| `<C-S-Space>` / `:Neotree toggle` | n | Toggle sidebar file explorer |
| `a` | Neo-tree | Create new file or directory (ending with `/`) |
| `d` | Neo-tree | Delete file/folder |
| `r` | Neo-tree | Rename item |
| `c` | Neo-tree | Copy item |
| `m` | Neo-tree | Move item |

---

### 🌿 Neogit & Diffview (Version Control)

| Shortcut | Mode | Action |
|---|---|---|
| `<C-S-g>` | n | Toggle Git sidebar (status, staged/unstaged, commits) |
| `<Enter>` | Neogit Status | Open diff in vertical split |
| `d` | Neogit Status | Quick diff preview |

---

### 📑 Bufferline (Buffer Tabs)

| Shortcut | Mode | Action |
|---|---|---|
| `gt` / `<A-l>` / `<A-Right>` | n | Jump to next buffer |
| `gT` / `<A-h>` / `<A-Left>` | n | Jump to previous buffer |
| `<C-A-Left>` | n | Move current tab left |
| `<C-A-Right>` | n | Move current tab right |

---

### 📦 package-info (npm / pnpm / bun dependencies)

| Shortcut | Mode | Action |
|---|---|---|
| `<leader>ns` | n | Show inline package versions in `package.json` |
| `<leader>nc` | n | Hide inline package versions |
| `<leader>nu` | n | Update package under cursor |
| `<leader>nd` | n | Delete package under cursor |
| `<leader>ni` | n | Install new package |
| `<leader>np` | n | Change package version |

---

### ⚡ Autocompletion (Blink.cmp)

| Shortcut | Mode | Action |
|---|---|---|
| `<CR>` | Insert | Accept highlighted completion item |
| `<C-space>` / `<C-@>` | Insert | Trigger completion menu / documentation |
