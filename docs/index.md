# 🦊 KrsVim Wiki

Welcome to the **KrsVim** documentation! KrsVim is a fast, Windows-first, WSL-aware Neovim distribution built around a modular architecture and rounded floating UI modules (`lua/plugins/krs/`).

---

## 🏁 New User Quick Start (First 5 Minutes)

If you have just installed or launched KrsVim for the first time, follow these steps:

1. **Start Neovim**: Run `nvim` in your terminal. On first startup, `lazy.nvim` automatically downloads and installs all editor plugins.
2. **Open the Dashboard & Wiki**: If you land on the dashboard screen, press `w` to open this Wiki inside Neovim (or run `:NvimWiki` from anywhere).
3. **Sync External Dependencies**: KrsVim relies on a few external CLI utilities (like `ripgrep`, `fd`, `gcc`, `chafa`, `node`, `bun`, `go`, `dotnet`). Run the automated setup script for your platform:
   - **Windows (PowerShell)**: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`
   - **Linux / WSL / Git Bash**: `./setup.sh`
   *(These scripts are idempotent—safe to run at any time! If you haven't run them yet, KrsVim will still run with [graceful fallbacks](installation.md#⚡-what-if-you-havent-run-setupps1-or-setupsh).)*
4. **Discover Shortcuts**: Press `<C-S-p>` to launch the **Command Palette**, or press `?` / `<F1>` in any window to get instant, context-aware keyboard help.

---

## 📌 Table of Contents

### 🏁 Getting Started & Setup
| Page | Contents |
| :--- | :--- |
| ⚙️ [**Installation & Dependencies**](installation.md) | Setup scripts (`setup.ps1` / `setup.sh`), Scoop/APT commands, health checks & graceful fallbacks |
| 🛠️ [**Languages, LSP & Formatting**](languages.md) | Mason servers, Conform formatters, Treesitter parsers & completion tuning |
| 🌐 [**Adding a Language / LSP**](adding-language.md) | Step-by-step guide for adding new language servers, formatters & debuggers |
| 📦 [**Plugin Inventory**](plugins.md) | Comprehensive listing of third-party plugins and custom `krs` modules |

### ⌨️ Daily Driving & Workflow
| Page | Contents |
| :--- | :--- |
| ⌨️ [**Keybinds Reference**](keybinds.md) | Full shortcut reference categorized by domain |
| 🧰 [**Command Palette**](command-palette.md) | `<C-S-p>` launcher, command registration & fuzzy action runner |
| 🗂️ [**Workspaces & Sessions**](workspaces.md) | Per-project session slots (`<C-S-w>`), tab persistence & buffer cleanups |
| 🐙 [**Git Control Center**](git-center.md) | Interactive Git staging, restore, commit form & submodules (`<C-S-g>`) |
| 📁 [**File Explorers**](file-explorer.md) | Desktop & WSL explorers (`<C-S-f>`), project pickers & Neo-tree integration |
| 🖥️ [**Multi-Terminal Manager**](terminals.md) | 9 independent terminal buffers (`<A-1>`..`<A-9>`), height memory & auto-WSL |
| 🎛️ [**Editor Quality of Life**](editor-qol.md) | Smart quit, context help (`?`/`<F1>`), colorscheme preview, image viewer (`<leader>i`), font sizing & PHP diagnostics |
| 🎨 [**Color Palette & Themes**](color-palette.md) | HSL palette architecture and live theme swapping |

### 🚀 Building, Running & Debugging
| Page | Contents |
| :--- | :--- |
| 🛠️ [**Task Runner**](tasks.md) | Auto-discovery build tasks, custom command chains & 4 background output slots (`<C-1..4>`) |
| 🚀 [**Launch Profiles**](launch-profiles.md) | `.krsnvim/launch.json`, smart launch (`<C-S-s>`), profile manager (`<C-S-q>`) & dev-server bridge |
| 🐞 [**Debug Adapters (DAP)**](debug-adapters.md) | Full debugger guide, Bun adapter, repl completion & troubleshooting |
| 🔴 [**Breakpoints**](breakpoints.md) | Session breakpoint persistence (`.krsnvim/breakpoints.json`), conditional breakpoints & logpoints |

### 🧬 Code Helpers & Tooling
| Page | Contents |
| :--- | :--- |
| 🌬️ [**Tailwind Organizer**](tailwind-organizer.md) | Automatic multi-row class sorting on save (`<leader>tw`) |
| 🧬 [**Type Injector**](type-injector.md) | Per-project Lua/TS type schemas and `@types` installer (`:TypeInjector`) |
| 📝 [**Input Modal Component**](input-modal.md) | Unified rounded floating input dialog replacing standard `vim.ui.input` |
| 📄 [**JSON Schemas**](schemas-json.md) / [**TOML Schemas**](schemas-toml.md) | Local schema catalogs, auto-completion & validation |

### 🏛️ Architecture & Extension
| Page | Contents |
| :--- | :--- |
| 🏛️ [**Architecture Overview**](architecture.md) | Four-layer architecture, startup sequence & dependency graph |
| 🧩 [**Module Architecture**](module-architecture.md) | How `lua/plugins/krs` modules self-register with `lazy.nvim` |
| 📶 [**Dynamic Z-Index Manager**](z-index.md) | Centralized Z-index stack manager (`krs.core.z_index`) for floating windows |
| 🧪 [**Testing Suite**](testing.md) | Running unit & integration tests (`:KrsTest`, `tests/run.lua`) |

---

## 🚀 Key Shortcuts at a Glance

| Shortcut | Action / Feature |
| :--- | :--- |
| `<C-S-m>` | Dashboard / Main Menu |
| `<C-S-p>` | Command Palette |
| `<C-S-w>` | Workspaces Picker |
| `<C-S-g>` | Git Control Center |
| `<C-S-f>` | Desktop File Explorer |
| `<C-S-t>` | Task Runner Menu |
| `<C-S-s>` | Run Default Launch Profile / Stop Debug Session |
| `<C-S-q>` | Launch Profile Manager |
| `<C-b>` | Toggle Breakpoint |
| `<C-;>` | Toggle Active Terminal |
| `<A-1>`..`<A-9>` | Switch to Terminal Slot 1..9 |
| `?` / `<F1>` | Context-Aware Help for Focused Window |

---

## 🚀 Core Design Philosophy

1. **Everything is a Local Module**: All custom features live in `lua/plugins/krs/*.lua` as single-file lazy specs backed by pure testable modules in `lua/krs/`.
2. **Per-Project State (`.krsnvim/`)**: Tasks, launch profiles, breakpoints, and type definitions stay inside your project directory rather than polluting global editor state.
3. **First-Class Debugging**: Pre-configured DAP adapters for JS/TS, Bun, Python, Go, C#, PHP, C/C++, and Rust with persistent breakpoints and REPL integration.
4. **Unified Floating UI**: Input popups, file pickers, git controls, and terminals share a cohesive rounded design system managed by a centralized [Z-Index Manager](z-index.md).
5. **Multi-Layout Support**: Built-in compatibility for US Standard, US-International, Latam, and European keyboards.
