# 📋 Snippets Manager (`:SnippetManager`)

The **KrsVim Snippet Manager** allows you to create, edit, override, delete, and list snippets per language in standard VSCode JSON format (`.json`), seamlessly integrated into Neovim's `blink.cmp` autocompletion engine.

---

## 🚀 Key Commands

| Command | Action |
| :--- | :--- |
| `:SnippetManager` / `:KrsSnippetManager` | Open the main Snippet Manager UI menu |
| `:KrsSnippetEdit [language]` | Open or create the snippets JSON file for a language (e.g. `:KrsSnippetEdit lua`) |
| `:KrsSnippetAdd [language]` | Interactively prompt for Snippet Name, Prefix, Body, and Description |
| `:KrsSnippetReload` | Force reload snippet definitions in `blink.cmp` |

You can also access all snippet features via the **Command Palette** (`<C-S-p>`) under the **Snippets** category.

---

## 📁 File Location & Format

Snippets are stored inside your Neovim configuration folder:
```
nvim/snippets/<language>.json
```

### Example `snippets/lua.json`:
```json
{
  "Lua Module Boilerplate": {
    "prefix": "mod",
    "body": [
      "local M = {}",
      "",
      "function M.setup(opts)",
      "    ${0}",
      "end",
      "",
      "return M"
    ],
    "description": "Standard Lua module template"
  }
}
```

---

## 🔄 Live Reload & Integration
Custom snippets are stored in VSCode format so they are compatible with standard snippet engines and `blink.cmp`. Whenever you update a snippet file via `:KrsSnippetEdit` or `:KrsSnippetAdd`, the snippets become immediately available during completion.
