# ⚙️ Installation & External Dependencies

Clone into the Neovim config directory (`%LOCALAPPDATA%\nvim` on Windows, `~/.config/nvim` on Linux) and start `nvim` — `lazy.nvim` bootstraps itself, then Mason installs the servers, formatters and debug adapters listed in [Languages, LSP & Formatting](languages.md).

The CLIs below are **not** installed by Mason and must exist on `PATH`.

---

## 🚀 Quick install (Windows / Scoop)

```powershell
scoop bucket add main
scoop bucket add extras
scoop install neovim git ripgrep fd chafa gcc nodejs-lts go dotnet-sdk
```

---

## 📋 Dependency breakdown

| Tool / CLI | Purpose in config | Scoop (Windows) | Linux / WSL package |
|---|---|---|---|
| **Neovim** (>= 0.10) | Core editor | `scoop install neovim` | `neovim` |
| **Git** | Mason, Neogit, lazy.nvim, Git Control Center, Bun adapter checkout | `scoop install git` | `git` |
| **ripgrep** (`rg`) | Telescope live grep (`<C-f>`) | `scoop install ripgrep` | `ripgrep` |
| **fd** | Faster file finding for Telescope | `scoop install fd` | `fd-find` / `fd` |
| **chafa** | Terminal image previewer (`<leader>i`) | `scoop install chafa` | `chafa` |
| **GCC / MinGW** | Compiling Treesitter parsers | `scoop install gcc` | `gcc` / `build-essential` |
| **Node.js & npm** | JS/TS LSP, JSON/HTML/CSS LSPs, Prettier, `js-debug-adapter` | `scoop install nodejs-lts` | `nodejs npm` |
| **Go** | `gopls`, `gofumpt`, `goimports`, `delve` | `scoop install go` | `golang` |
| **.NET SDK** (`dotnet`) | C# LSP, Nuget manager, `netcoredbg` | `scoop install dotnet-sdk` | `dotnet-sdk` |
| **WSL** *(optional, Windows)* | WSL file explorer, auto-WSL terminals | `wsl --install` | — |

### Optional, per language you actually debug

| Tool | Needed for |
|---|---|
| **Bun** | Bun launch profiles and the Bun debug adapter (see [Debug Adapters](debug-adapters.md)) |
| **Python** (+ project `.venv`) | `debugpy`; the venv interpreter is preferred over `PATH` |
| **PHP + Composer + Xdebug** | PHP debugging — run `:PHPCheckTools` for a diagnostic modal (host and WSL are both probed) |
| **Chrome / Edge / Firefox** | Browser debug configurations |

---

## 📂 Per-project files this config writes

All under the project root, created only when a feature is actually used:

| File | Written by |
|---|---|
| `.krsnvim/tasks.json` | [Task runner](tasks.md) |
| `.krsnvim/launch.json` | [Launch profiles](launch-profiles.md) |
| `.krsnvim/breakpoints.json` | [Breakpoints](breakpoints.md) |
| `.krsnvim/types.json`, `.krsnvim/types.d.ts` | [Type injector](type-injector.md) |

`.krslocal/` (and, for some modules, `.nvimkrs/`) are honoured as alternative directory names when they already exist — handy when `.krsnvim/` is committed and you want machine-local overrides beside it.

> Nothing is created just to record "empty". A project with no breakpoints never grows a `.krsnvim/`.

---

## 🖋️ Font

Font size is persisted in `font_config.json` at the config root and changed live with `<C-+>` / `<C-->` / `<C-0>` (or `:FontSizeIncrease` / `:FontSizeDecrease` / `:FontSizeReset`). A Nerd Font is required for the icons in the dashboard, bufferline, explorers and DAP signs.
