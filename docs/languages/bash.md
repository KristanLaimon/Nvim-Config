# 🐚 Shell & Bash Development Suite

[← Back to Wiki Index](../index.md) | [← Back to Languages Overview](../languages.md)

KrsVim provides shell script editing, syntax validation via ShellCheck, formatting, and debugging via `bash-debug-adapter`.

---

## 🛠️ Toolchain Summary

| Feature | Tool / Package | Details |
| :--- | :--- | :--- |
| **Language Server (LSP)** | `bashls` | Shell script LSP (`sh`, `bash`, `zsh`, `csh`, `ksh`) with ShellCheck integration |
| **Formatters (Conform)** | `beautysh` | Indentation and format cleanup for shell scripts |
| **Treesitter Parsers** | `bash` | Full syntax tree for Bash / Shell scripts |
| **Autocompletion** | `blink.cmp` | Command name, path, and variable autocompletion |
| **Debug Adapter (DAP)** | `bash-debug-adapter` / `bashdb` | Step-by-step debugging for Bash scripts |

---

## 🧰 Ex Commands & Command Palette Actions

Accessible via **Command Palette** (`<C-S-p>` / `:CommandPalette`):

* `:FormatDocument` – Format active shell script using Beautysh.
* `:LanguageManager` – Install or uninstall Shell / Bash bundle.
