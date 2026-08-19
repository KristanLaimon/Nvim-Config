# 🤖 AGENTS.md — KrsVim AI Assistant Guidelines & Compact Wiki Reference

This file defines mandatory guidelines and reference links for AI coding assistants working in or customizing this Neovim distribution (**KrsVim**).

> 🌐 **Per-Language Documentation Reference**: Individual language toolchain guides, debug profiles, and LSP/formatter commands are documented under [`docs/languages/`](docs/languages/) (e.g., [`php.md`](docs/languages/php.md), [`typescript.md`](docs/languages/typescript.md), [`csharp.md`](docs/languages/csharp.md), [`go.md`](docs/languages/go.md), [`python.md`](docs/languages/python.md), [`lua.md`](docs/languages/lua.md), [`web.md`](docs/languages/web.md), [`docker-proto.md`](docs/languages/docker-proto.md), [`bash.md`](docs/languages/bash.md)).

---

## 📌 1. Mandatory Development & Architecture Guidelines

### 🌐 1.1 Language Additions & Tooling Registration Rule
When adding support for a new programming language (or updating an existing one):
1. **Update `installer.lua` (`M.language_bundles`)**: Add the language bundle specifying its Mason packages (`mason_pkgs`) and Treesitter parsers (`treesitter`).
2. **Add to Interactive Selection UI**: Ensure the language appears as an **optional selectable bundle** in the Language Tooling Manager (`:LanguageManager`, `:KrsLanguageManager`, `:KrsInstallDependencies`, `:KrsSetup`).
3. **Update LSP, Formatter, DAP & Wiki Specs**: Register server options in `lua/plugins/lsp/lsp.lua`, formatters in `lua/plugins/lsp/formatting.lua`, debugger profiles in `lua/plugins/krs/debuggers/<lang>.lua`, and document it in a dedicated file under [`docs/languages/<lang>.md`](docs/languages/).
4. **Per-Language Defaults in `lua/krs/langs/`**: Put all non-UI, non-plugin-specific language configuration (such as default indentation settings when no `.editorconfig` exists, environment path resolution, and language setup hooks) inside `lua/krs/langs/<language>/init.lua` and register the submodule in `lua/krs/langs/init.lua`.


### 🌙 1.2 Minimal Fresh Setup Rule (Lua Only)
* **Default Fresh Behavior**: On a fresh Neovim installation, the default toolchain installation MUST remain **minimal** (Lua language server `lua_ls`, `stylua` formatter, and core editor parsers `lua`, `vim`, `vimdoc`, `markdown` only).
* **No Background Heavy Installs**: Never auto-install optional language tools (PHP, TypeScript, Python, Go, C#, Docker, Shell) in the background without explicit user selection.
* **UI Selection**: Users choose which optional language toolchains to install using the UI selection menu:
  - **`Select All` (`a`)**: Selects all optional language bundles for installation.
  - **`Select None` (`n`)**: Deselects optional languages, reverting to minimal Lua core.
  - **`Per-Row Toggle` (`Space` / `Enter`)**: Selects/deselects individual language bundles (e.g. PHP & Laravel).

### 🧰 1.3 Command Palette Preference (No `<leader>` Shortcuts)
* **Prefer Command Palette Commands**: Always prefer registering actions and tools in the **Command Palette** (`<C-S-p>` or `:CommandPalette`) over assigning `<leader>` keymaps.
* **Command Registration**: Add user-facing features to `M.commands` in `lua/plugins/krs/command_palette.lua` with descriptive names and categories.
* **Ex Commands**: Provide explicit User Commands (e.g., `:FormatDocument`, `:PHPCheckTools`, `:BladeNavClearCache`) so actions are discoverable via Neovim command-line completion and palette search.

---

## 🏛️ 2. Neovim Architecture Summary

KrsVim follows a modular four-layer design:
1. **`lua/config/`**: Core options (`options.lua`), global keymaps (`keymaps/`), and plugin manager entry (`lazy.lua`).
2. **`lua/krs/`**: Pure, testable core modules (UI float helpers, installer, workspace sessions, project path resolution, Z-index manager).
3. **`lua/plugins/`**: Plugin specifications loaded by `lazy.nvim`:
   - `lua/plugins/editor/`: Core editor plugins (Telescope, Neo-tree, DAP, Treesitter).
   - `lua/plugins/lsp/`: LSP configs (`lsp.lua`), formatters (`formatting.lua`), autocompletion (`blink.cmp`), and Laravel support (`laravel.lua`).
   - `lua/plugins/krs/`: KRS local UI modules (Command Palette, Task Runner, Git Center, Terminal Manager, Theme Picker).
4. **`.krsnvim/`**: Per-project config directory created in workspace roots holding tasks, launch profiles, breakpoints, and local script definitions.

---

## 📚 3. Wiki Sitemap & Comprehensive Use-Case Index

Refer to the specific wiki documentation page for each feature or development use case:

### 🏁 Getting Started & System Setup
* ⚙️ [**Installation & System Dependencies**](docs/installation.md) — Setup scripts (`setup.ps1` / `setup.sh`), Scoop/APT commands, health checks & fallbacks.
* 🌱 [**Neovim Basics**](docs/neovim-basics.md) — Buffers, windows, tabs, and VSCode-style editing fundamentals.
* 🎓 [**How-To & Customization Guide**](docs/how-to-customize-editor.md) — Step-by-step guide for adding plugins, local modules, and custom themes.
* 🛠️ [**Languages, LSP & Formatting**](docs/languages.md) — Mason package definitions, Conform formatter pipelines & Treesitter parser setup.
* 🌐 [**Adding a Language / LSP**](docs/adding-language.md) — Walkthrough for integrating a new language server, formatter, and DAP profile.
* 📦 [**Plugin Inventory**](docs/plugins.md) — Full index of built-in `lua/plugins/krs/` modules and third-party lazy plugins.

### ⌨️ Daily Driving & Workflow Use Cases
* 🧰 [**Command Palette**](docs/command-palette.md) — `<C-S-p>` action runner, command registration API & fuzzy search.
* ⌨️ [**Keybinds Reference**](docs/keybinds.md) — Comprehensive keyboard shortcuts organized by feature domain.
* 🗂️ [**Workspaces & Sessions**](docs/workspaces.md) — Per-project session slots (`<C-S-w>`), tab persistence & buffer cleaner.
* 🐙 [**Git Control Center**](docs/git-center.md) — Interactive staging, side-by-side diffs, branch switcher & commit form (`<C-S-g>`).
* 📁 [**File Explorers**](docs/file-explorer.md) — Desktop & WSL file browsers (`<C-S-f>`) and Neo-tree sidebar integration.
* 🖥️ [**Multi-Terminal Manager**](docs/terminals.md) — 9 background terminal slots (`<A-1>`..`<A-9>`), height memory & toggle (`<C-;>`).
* 🎛️ [**Editor Quality of Life**](docs/editor-qol.md) — Context-aware help (`?`/`<F1>`), image viewer (`:ImageViewer`), theme picker & font sizing.
* 🎨 [**Color Palette & Themes**](docs/color-palette.md) — NvChad/Nagatoro theme architecture and palette switcher (`:KrsThemePicker`).

### 🚀 Tasks, Launch Profiles & Debugging Use Cases
* 🛠️ [**Task Runner**](docs/tasks.md) — Auto-discovered build/test tasks (`<C-S-t>`) & background output slots (`<C-1..4>`).
* 🚀 [**Launch Profiles**](docs/launch-profiles.md) — `.krsnvim/launch.json` profile manager (`<C-S-q>`) & default launcher (`<C-S-s>`).
* 🐞 [**Debug Adapters (DAP)**](docs/debug-adapters.md) — Interactive debugging launcher (`<F5>`), REPL completion & adapter setup.
* 🔴 [**Breakpoints Management**](docs/breakpoints.md) — Persistent breakpoints (`<C-b>`), conditional breakpoints, and `.krsnvim/breakpoints.json`.
* 🧪 [**Testing Suite**](docs/testing.md) — Running unit tests for local config modules (`:KrsTest`).

### 🧬 Code Helpers & Tooling Use Cases
* 🌬️ [**Tailwind Class Organizer**](docs/tailwind-organizer.md) — Multi-row class sorting on save or on command (`:TailwindOrganize`).
* 🧬 [**Type Injector**](docs/type-injector.md) — Per-project Lua & TypeScript type definitions manager (`:TypeInjector`).
* 📝 [**Input Modal Dialog**](docs/input-modal.md) — Rounded floating dialog for `vim.ui.input`.
* 📄 [**JSON Schemas Catalog**](docs/schemas-json.md) & [**TOML Schemas Catalog**](docs/schemas-toml.md) — Local offline validation schemas.

---

## 🌐 4. Supported Language Guides (`docs/languages/`)

Detailed setup, Ex commands, DAP debug profiles, and plugin integrations for each supported language:

* 🐘 [**PHP & Laravel Guide**](docs/languages/php.md) — Intelephense, Pint, PHP-CS-Fixer, blade-formatter, `blade-nav.nvim`, Xdebug (`:PHPCheckTools`, `:BladeNavClearCache`, `:FormatDocument`).
* 🟨 [**TypeScript & JavaScript Guide**](docs/languages/typescript.md) — `vtsls`, ESLint, Biome, Prettier/Prettierd, `js-debug-adapter`, `type-injector`, `tailwind-organizer`.
* 🎯 [**C# / .NET / Blazor Guide**](docs/languages/csharp.md) — OmniSharp, `csharp-ls`, CSharpier, `netcoredbg` (Blazor Server & DLL debugging), `:DotnetNew`, `:NugetManager`.
* 🟦 [**Go Guide**](docs/languages/go.md) — `gopls`, `delve` DAP (`nvim-dap-go`), `gofumpt`, `goimports`.
* 🐍 [**Python Guide**](docs/languages/python.md) — `pyright`, `debugpy` DAP, `black`, `isort`, `ruff`.
* 🌙 [**Lua & KrsVim Scripts Guide**](docs/languages/lua.md) — `lua_ls`, `stylua`, `type_injector`, `krsnvimtranspiler` (`:KrsTranspile`).
* 🌐 [**Web Frontend Guide**](docs/languages/web.md) — HTML, CSS, Svelte, Astro, Tailwind CSS, Emmet, `autotag`, `:TailwindOrganize`.
* 🐳 [**Docker & Proto Guide**](docs/languages/docker-proto.md) — `dockerls`, `dockerfmt`, `protolint`.
* 🐚 [**Shell & Bash Guide**](docs/languages/bash.md) — `bashls`, `bash-debug-adapter`, `beautysh`, ShellCheck.

---

## ⚡ Quick Rule Summary for AI Assistants

> [!IMPORTANT]
> 1. **Always keep fresh setups minimal** (Lua core only).
> 2. **Always list new languages in `:LanguageManager`** as optional UI selections.
> 3. **Prefer Command Palette options** over assigning `<leader>` keymaps.
> 4. **Reference dedicated wiki pages** under [`docs/languages/`](docs/languages/) for language-specific toolchain details.
> 5. **Place all non-UI, non-plugin per-language defaults** in `lua/krs/langs/<language>/init.lua` and register them in `lua/krs/langs/init.lua`.

