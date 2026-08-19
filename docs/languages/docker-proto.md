# 🐳 Docker & Protocol Buffers Suite

[← Back to Wiki Index](../index.md) | [← Back to Languages Overview](../languages.md)

KrsVim provides editing, validation, and formatting for **Dockerfiles** and **Protocol Buffer (`.proto`)** definitions.

---

## 🛠️ Toolchain Summary

| Feature | Tool / Package | Details |
| :--- | :--- | :--- |
| **Language Server (LSP)** | `dockerls` | Dockerfile linting and validation |
| **Formatters (Conform)** | `dockerfmt`, `protolint` | Dockerfile and Protobuf code formatting |
| **Treesitter Parsers** | `editorconfig`, `proto` | Syntax trees for `.editorconfig` and `.proto` |
| **Autocompletion** | `blink.cmp` | Keyword and path completion for Docker instructions and proto schemas |

---

## 🧰 Ex Commands & Command Palette Actions

Accessible via **Command Palette** (`<C-S-p>` / `:CommandPalette`):

* `:FormatDocument` – Format Dockerfile or `.proto` file.
* `:LanguageManager` – Install or uninstall Docker & Proto bundle.
