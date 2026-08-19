# 🌙 Lua & KrsVim Script Development Suite

[← Back to Wiki Index](../index.md) | [← Back to Languages Overview](../languages.md)

KrsVim provides full editing and transpilation support for **Lua** and local `.krsnvim` scripts (`krsnvimtranspiler`).

---

## 🛠️ Toolchain Summary

| Feature | Tool / Package | Details |
| :--- | :--- | :--- |
| **Language Server (LSP)** | `lua_ls` | Configured with Neovim API globals (`vim`) and `.krsnvim` script globals (`fetch`, `console`, `import`, `cli`, `terminal`, `fs`) |
| **Formatters (Conform)** | `stylua` | Opinionated Lua code formatting |
| **Treesitter Parsers** | `lua` | Full syntax trees for Lua and `.krsnvim` scripts |
| **Autocompletion** | `blink.cmp` + `krsnvim_cmp` | Neovim Lua API completion + `.krsnvim` library completion |
| **Transpiler** | `krsnvimtranspiler` | Transpiles `.krsnvim` scripts to cross-platform Bash (`.sh`) and PowerShell (`.ps1`) |

---

## 🧰 Ex Commands & Command Palette Actions

Accessible via **Command Palette** (`<C-S-p>` / `:CommandPalette`):

* `:FormatDocument` – Format active Lua file using StyLua.
* `:KrsTranspile` – Transpile active `.krsnvim` script.
* `:KrsTranspileSh` – Transpile `.krsnvim` script to Bash (`.sh`).
* `:KrsTranspilePs1` – Transpile `.krsnvim` script to PowerShell (`.ps1`).
* `:KrsTranspileBoth` – Transpile `.krsnvim` script to both `.sh` and `.ps1`.
* `:LanguageManager` – Manage Lua language bundle.
