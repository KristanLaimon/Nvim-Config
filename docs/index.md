# 🦊 KrsVim Wiki

Documentation for **KrsVim** — a Windows-first, WSL-aware Neovim config built around floating UI modules in `lua/plugins/krs/`.

---

## 📌 Table of Contents

### Setup
| Page | Contents |
| :--- | :--- |
| ⚙️ [**Installation & Dependencies**](installation.md) | External CLIs, Scoop one-liner, what each tool is used for |
| 🛠️ [**Languages, LSP & Formatting**](languages.md) | Mason servers, Conform formatters, Treesitter parsers, completion tuning |
| 🌐 [**Adding a Language / LSP**](adding-language.md) | Step-by-step for a new server, formatter and parser |
| 📦 [**Plugin Inventory**](plugins.md) | Every third-party plugin and every custom `krs` module |
| 🏛️ [**Architecture**](architecture.md) | The four layers, startup sequence, dependency graph, where to put new code |
| 🧩 [**Module Architecture**](module-architecture.md) | How `lua/plugins/krs` specs are wired, and the `lazydir` fix behind it |
| 🧪 [**Testing**](testing.md) | Running the suite, writing a spec, what is covered |

### Daily driving
| Page | Contents |
| :--- | :--- |
| ⌨️ [**Keybinds**](keybinds.md) | Full shortcut reference, by domain |
| 🧰 [**Command Palette**](command-palette.md) | `<C-S-p>` launcher and how to register commands |
| 🗂️ [**Workspaces & Sessions**](workspaces.md) | Per-project session slots (`<C-S-w>`) |
| 🐙 [**Git Control Center**](git-center.md) | Staging, restore, push, commit form (`<C-S-g>`) |
| 📁 [**File Explorers**](file-explorer.md) | Desktop & WSL explorers, folder picker, Neo-tree move picker |
| 🖥️ [**Multi-Terminal Manager**](terminals.md) | 9 terminals, `<A-1>`..`<A-9>`, auto-WSL |
| 🛠️ [**Task Runner**](tasks.md) | Per-project tasks, chains, background output slots |
| 🎛️ [**Editor Quality of Life**](editor-qol.md) | Smart quit, context help, colorscheme preview, image viewer, font sizing, Nuget, PHP tool check |
| 🎨 [**Color Palette & Themes**](color-palette.md) | Palette architecture and theme swapping |

### Running & debugging code
| Page | Contents |
| :--- | :--- |
| 🚀 [**Launch Profiles**](launch-profiles.md) | `.krsnvim/launch.json`, smart launch (`<C-S-s>`), profile editor (`<C-S-q>`), dev-server bridge |
| 🐞 [**Debug Adapters (DAP)**](debug-adapters.md) | How debugging works end to end, per-language debugger modules, diagnosing a silent adapter |
| 🔴 [**Breakpoints**](breakpoints.md) | Persistence across sessions, disabled breakpoints, conditions & logpoints |

### Codegen & schemas
| Page | Contents |
| :--- | :--- |
| 🌬️ [**Tailwind Organizer**](tailwind-organizer.md) | Multi-row class sorting on save |
| 🧬 [**Type Injector**](type-injector.md) | Per-project Lua/TS type schemas and `@types` installer |
| 📝 [**Input Modal Component**](input-modal.md) | The reusable floating input used everywhere |
| 📄 [**JSON Schemas**](schemas-json.md) / [**TOML Schemas**](schemas-toml.md) | Local schema catalogs and validation |

---

## 🚀 What makes this config different

1. **Everything is a local module.** `lua/plugins/krs/*.lua` files are real lazy.nvim specs that live in-repo — no plugin repos, no `setup()` boilerplate. Shared logic sits one layer below in `lua/krs/`, where it is unit-testable. See [Architecture](architecture.md).
2. **Per-project state, not global state.** Tasks, launch profiles, breakpoints and type schemas are stored under `.krsnvim/` in the project itself (`tasks.json`, `launch.json`, `breakpoints.json`, `types.json`).
3. **A real debugger story.** Seven languages wired through per-language modules, plus a Bun adapter that VSCode never shipped standalone, a repl completion source that asks the debug adapter instead of the buffer, and breakpoints that survive a restart.
4. **Unified floating UI.** Input prompts, diagnostics, code actions, terminals, git and file explorers all use the same rounded floating look, with `vim.ui.input` globally overridden by [`input_modal`](input-modal.md).
5. **Two keyboard layouts.** US Standard and US-International both mapped (`<C-'>`, `<C-/>`, `<C-_>`, `<C-S-'>`), and terminal mode handled without PTY character leakage.

---

## 💡 Quick launch shortcuts

| Shortcut | Opens |
| :--- | :--- |
| `<C-S-m>` | Dashboard / main menu |
| `<C-S-p>` | Command palette |
| `<C-S-w>` | Workspaces picker |
| `<C-S-g>` | Git Control Center |
| `<C-S-f>` | Desktop file explorer |
| `<C-S-t>` | Project tasks menu |
| `<C-S-s>` | Run default launch profile / stop the running session |
| `<C-S-q>` | Launch profile manager |
| `<C-b>` | Toggle breakpoint |
| `<C-;>` | Toggle active terminal |
| `<A-1>`..`<A-9>` | Select terminal #1..9 |
| `?` / `<F1>` | Context-aware help for whatever is focused |
