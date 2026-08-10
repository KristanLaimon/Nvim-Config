```

            /\   /\
           ( ..   .. )      _  __ ____  ____
            \  Y  /        | |/ /|  _ \/ ___|
         /\_/\   /\_/\     | ' / | |_) \___ \
        (  o o     o o)    | . \ |  _ < ___) |
         \  ~   ~  /       |_|\_\|_| \_\____/
          \___^___/

```

# 🦊 KrsVim - An orange-fox nvim tailored for fox coders

![krsnv-cover](./.github/cover.png)
![krsnv-cover](./.github/editor-example.png)


This is my personal Neovim setup, I think it can be considered a mini-distro, but if you like it go ahead and use it! or fork it. I'm just documenting it here so I remember how it works for my future-self, and in case I broke something while editing this setup haha.
Expect sharp edges, highly opinionated features, and things wired specifically to how *I* work in my day-to-day

Built for Windows as first-class-support with WSL support layered on top (file browsing, terminals, the works) and it should mostly hold up on plain Linux too, if that's not the case, feel free to open an PR or issue, i'll fix it ASAP 🦊

---

## ⚙️ System Requirements & External Dependencies

For everything to work (fuzzy finding, the floating file explorers, image previews, LSP auto-install, Treesitter parser compiling, Git integration), install these via **Scoop** on Windows (or your distro's package manager on Linux/WSL):

### 🚀 Quick Scoop Install (Windows)
```powershell
scoop bucket add main
scoop bucket add extras
scoop install neovim git ripgrep fd chafa gcc nodejs-lts go dotnet-sdk
```

### 📋 Dependency Breakdown

| Tool / CLI | Purpose in Config | Scoop Command (Windows) | Linux / WSL Package |
|---|---|---|---|
| **Neovim** (>= 0.10) | Core editor | `scoop install neovim` | `neovim` |
| **Git** | Mason, Neogit, Lazy plugin manager | `scoop install git` | `git` |
| **ripgrep** (`rg`) | Telescope live grep (`<C-f>`) | `scoop install ripgrep` | `ripgrep` |
| **fd** | Faster file finding for Telescope | `scoop install fd` | `fd-find` / `fd` |
| **chafa** | Terminal image previewer (`<leader>i`) | `scoop install chafa` | `chafa` |
| **GCC / MinGW** | Compiling Treesitter parsers | `scoop install gcc` | `gcc` / `build-essential` |
| **Node.js & npm** | JS/TS LSP (`ts_ls`), JSON/HTML/CSS LSPs, Prettier | `scoop install nodejs-lts` | `nodejs npm` |
| **Go** | `gopls`, `gofumpt`, `goimports` | `scoop install go` | `golang` |
| **.NET SDK** (`dotnet`) | C# LSP (`omnisharp`), Nuget package manager | `scoop install dotnet-sdk` | `dotnet-sdk` |
| **WSL** *(optional, Windows only)* | WSL file explorer & auto-WSL terminals | `wsl --install` | — |

---

## 🛠️ Languages, LSP, Formatters & Parsers (Mason & Treesitter)

Mason, Conform and Treesitter are preconfigured to install and manage everything below automatically — no manual `:MasonInstall` needed.

| Language / Environment | LSP Server | Formatters (Conform) | Treesitter Parser |
|---|---|---|---|
| **Lua** | `lua_ls` | `stylua` | `lua` |
| **JSON** | `jsonls` *(SchemaStore auto)* | `prettierd` / `prettier` | `json` |
| **JavaScript / TS / React** | `ts_ls` | `prettierd` / `prettier` | `javascript`, `typescript`, `tsx` |
| **HTML / CSS** | `cssls` / `html` | `prettierd` / `prettier` | `html`, `css` |
| **Svelte / Astro** | `svelte`, `astro` | `biome` (default) — `.astro` always uses `prettier` (needs `prettier-plugin-astro` installed in the project; biome can't format `.astro` templates at all) | `svelte`, `astro` |
| **Go** | `gopls` | `gofumpt`, `goimports` | `go`, `gomod`, `gowork`, `gosum` |
| **C# / .csproj** | `omnisharp` (`.cs`), `lemminx` (`.csproj`, `.props`, `.targets` — treated as XML) | — | `c_sharp` |
| **YAML / TOML** | `yamlls`, `taplo` | — | `yaml`, `toml` |
| **Markdown** | — | — | `markdown`, `markdown_inline` |
| **Config / Data** | — | — | `vim`, `vimdoc` |

- **JSON Schema Validation** via `schemastore.nvim` — autocompletion and live validation in `package.json`, `tsconfig.json`, `.eslintrc`, etc.
- **Format on Save** via `conform.nvim` (`timeout_ms = 1000`, `lsp_fallback = true`).
- **C# IntelliSense** comes from `omnisharp` reading the project's `.csproj`/`.sln`; you don't need to open the solution manually, it resolves from the working directory.

#### ➕ Adding a new Treesitter language

`lua/plugins/lsp/treesitter.lua` pins `nvim-treesitter` to the `main` branch (the rewrite), which dropped the old `highlight.enable` config — highlighting is started per-buffer via a `FileType` autocmd that calls `vim.treesitter.start()` on any filetype, `pcall`'d so it silently no-ops when there's no parser installed. To add a language:

1. Add the parser name to the `parsers` list at the top of `lua/plugins/lsp/treesitter.lua`.
2. `:TSUpdate` (or restart Neovim — `ts.install(parsers)` runs on setup).

No autocmd/pattern changes needed — it already matches every filetype.

---

## 📦 Installed Plugins & Custom Modules

### 🛠️ Custom-Tailored Plugins & Modules (`lua/plugins/krs`, `lua/config/krs`)

| Feature | Location | What it does | Keybindings |
|---|---|---|---|
| **Workspaces Manager** | `lua/plugins/krs/workspaces.lua` | Harpoon + Telescope hybrid session manager. Saves buffers, tab layout and `cwd` per project into numbered slots; rename, overwrite, delete from a floating UI. | `<C-S-w>`, `<leader>ws`, `<leader>ww`, `<leader>wm`, `<leader>w1`..`9`, `<C-S-m>` |
| **Command Palette** | `lua/plugins/krs/command_palette.lua` | VSCode-style `Ctrl+Shift+P` fuzzy command list — runs Vim commands, simulated keypresses, or Lua functions from one picker. | `<C-S-p>` |
| **Git Control Center** | `lua/plugins/krs/git_center.lua` | Custom floating Git UI: stage/unstage, diff preview, commit form (title/description/tag), stash, and undo — no external Git plugin needed for the daily flow. | `<C-S-g>` |
| **Nuget Package Manager** | `lua/plugins/krs/nuget.lua` | CRUD for `<PackageReference>` in a `.csproj` via `dotnet add/remove package`, through a Telescope picker. Only activates when the project actually has a `.csproj`. | `<leader>ng`, `:NugetManager` |
| **Desktop File Explorer** | `lua/config/krs/file_explorer.lua` | Pure-Lua floating file browser (no external file-manager binary), starts at `~/Desktop`. Create/rename/delete files & folders, drill in/out, set a folder as the active project. | `<C-S-f>` |
| **WSL File Explorer** | `lua/config/krs/file_explorer.lua` | Same explorer, rooted at a WSL distro's filesystem (`\\wsl.localhost\<Distro>\`). Lists installed distros if there's more than one. Windows-only. | `<leader>fw`, `:TelescopeFileBrowserWSL` |
| **Open Folder Picker** | `lua/plugins/editor/telescope.lua` | Generic "open any folder as project" picker, independent of the Desktop explorer. | `<C-S-o>` |
| **Recent Projects** | `lua/plugins/editor/project.lua` | `project.nvim` wrapped in a custom picker with favorites (pinned to the bottom) and per-entry delete. | `<C-S-r>` |
| **Multi-Terminal Manager** | `lua/config/krs/terminal.lua` | 9 lazily-spawned terminals, toggle/select independently. If the terminal's `cwd` sits inside a WSL distro path, it launches `wsl.exe` there instead of the default Windows shell — automatic, no config needed. | `<A-1>`..`<A-9>`, `<C-;>` |
| **Task & Script Manager** | `lua/config/krs/tasks.lua` | Per-project tasks stored in `.krsnvim/tasks.json`; run, chain, or set a default task detected from `Makefile`/`package.json`/etc. | `<C-S-t>`, `<leader>ta`, `<C-S-a>` |
| **Live Colorscheme Previewer** | `lua/config/krs/colorscheme_preview.lua` | Previews the theme live as you tab through `:colorscheme <Tab>`, reverts if you cancel. | `:colorscheme <Tab>` |
| **Pixel-Art Image Viewer** | `lua/config/krs/image_viewer.lua` | Renders images as terminal pixel art via `chafa` in a floating window; can also hand off to the OS default app. | `<leader>i`, `<C-S-Enter>` |
| **Buffer Cleaner & Smart Quit** | `lua/config/krs/buffer_cleaner.lua` | Makes `:q` context-aware (close split → close tab → back to dashboard → quit), and sweeps empty `[No Name]` buffers automatically. | `:q` / `:q!` |
| **Context Help** | `lua/config/krs/context_help.lua` | `?` / `<F1>` shows a tiny, context-aware cheatsheet (different content in Neo-tree, Git, Telescope, editor). | `?`, `<F1>` |

### Core & LSP
| Plugin | Purpose |
|---|---|
| `neovim/nvim-lspconfig` | Native LSP server configuration |
| `williamboman/mason.nvim` | Package manager for LSPs, formatters & linters |
| `williamboman/mason-lspconfig.nvim` | Mason integration with nvim-lspconfig |
| `zapling/mason-conform.nvim` | Automatic installer for Conform formatters |
| `saghen/blink.cmp` | Fast completion engine (modern nvim-cmp replacement) |
| `rafamadriz/friendly-snippets` | Multi-language snippet collection |
| `stevearc/conform.nvim` | Fast asynchronous code formatter |
| `nvim-treesitter/nvim-treesitter` | Code highlighting and AST parsing |
| `b0o/schemastore.nvim` | JSON schemas for popular config files |

### Editor & Navigation
| Plugin | Purpose |
|---|---|
| `ThePrimeagen/harpoon` (v2) | Fast file bookmarking and navigation |
| `nvim-telescope/telescope.nvim` | Fuzzy finder |
| `nvim-tree/neo-tree.nvim` | Sidebar file explorer |
| `NeogitOrg/neogit` | Git interface sidebar |
| `sindrets/diffview.nvim` | Diff viewer and history for Neogit |
| `ahmedkhalf/project.nvim` | Project history backing the Recent Projects picker |
| `voldikss/package-info.nvim` | Inline `package.json` dependency management |
| `nvim-lua/plenary.nvim` | Lua utility library |

### Interface & Theme
| Plugin | Purpose |
|---|---|
| `goolord/alpha-nvim` | ASCII start dashboard |
| `doki-theme/doki-theme-vim` | Visual theme (Doki Theme) with a custom `#1e1e1e` background |
| `akinsho/bufferline.nvim` | Top buffer tab bar |
| `nvim-lualine/lualine.nvim` | Statusline |
| `nvim-highlight-colors` | Inline CSS color preview (hex, rgb, hsl) |
| `nvim-window-picker` | Visual window selector when opening files |
| `nvim-file-operations` | Auto rename/move sync between disk and buffers |

---

The rest of shortcuts and information in the "wiki" option in the main dashboard menu (when opening nvim with this config)
