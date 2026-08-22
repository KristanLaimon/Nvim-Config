# 🅰️ Angular

[← Back to Wiki Index](../index.md) | [← Back to Languages Overview](../languages.md)

KrsVim provides Angular Language Service integration for `.ts`/`.html` component files, plus SCSS diagnostics so Angular projects do not need the separate Web Frontend bundle for style completion.

---

## 🛠️ Toolchain Summary

| Feature | Tool / Package | Details |
| :--- | :--- | :--- |
| **Language Server (LSP)** | `angularls` (`angular-language-server`) | Angular Language Service — component template type-checking, go-to-definition, and diagnostics for `.ts` + `.html` pairs |
| **CSS / SCSS LSP** | `cssls` (`css-lsp`) | Bundled in the Angular language bundle so `.scss` files get diagnostics and completion without requiring the separate Web Frontend bundle |
| **Treesitter Parsers** | `html`, `scss` | Syntax highlighting for Angular templates and component stylesheets |
| **Requires** | `node` (Node.js) | Angular Language Server runs on Node.js; install from [nodejs.org](https://nodejs.org) |

> **Note**: TypeScript/JavaScript LSP (`vtsls`) and formatters (Prettier/Biome/ESLint) are provided by the **TypeScript & JavaScript** bundle, not this one. For full Angular development, install both the Angular bundle and the TypeScript bundle via `:LanguageManager`.

---

## 🧰 Ex Commands & Command Palette Actions

* `:LanguageManager` – Install or uninstall the Angular language bundle (`angularls`, `cssls`, Treesitter parsers).
* `:LspInfo` – Verify `angularls` is attached to the current buffer.

---

## 🔍 Notes

- **Root detection**: `angularls` uses nvim-lspconfig's default root markers (`angular.json`, `project.json`, `.git`). No custom `root_dir` override is needed.
- **Template type-checking**: Requires `@angular/core` to be present in `node_modules`; the language server resolves the compiler from the project's local install.
- **Formatting**: Handled by the TypeScript bundle's Prettier/Biome pipeline — Angular HTML templates are formatted as HTML.
