# File Explorer Configuration Guide

This guide details the two file explorer integrations available in this Neovim setup:
1. **Sidebar File Explorer (Neo-Tree)**
2. **Floating Desktop File Explorer (Pure Lua Telescope Explorer)**

---

## 📁 Key Files

- **Sidebar Explorer (Neo-Tree Plugin):** [`lua/plugins/editor/neo-tree.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/neo-tree.lua)
- **Floating Desktop Explorer:** [`lua/config/krs/file_explorer.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/krs/file_explorer.lua)

---

## 🌲 1. Sidebar File Explorer (Neo-Tree)

Neo-Tree provides a traditional sidebar tree view integrated into Neovim.

### Keybindings
- **Toggle Sidebar:** `<leader>e` or `<Ctrl+Shift+Space>`
- **Create File:** `<C-n>` (when focused in sidebar)
- **Create Directory:** `<C-S-n>` (when focused in sidebar)

### Width Persistence Architecture
Neo-Tree features automatic sidebar width persistence. When you resize the Neo-Tree window by dragging or resizing splits, Neovim saves the new width to `neotree_width` in the Neovim state directory (`stdpath("state")`) via a `WinResized` autocommand:

```lua
-- lua/plugins/editor/neo-tree.lua snippet
local group = vim.api.nvim_create_augroup("NeoTreeWidthSaver", { clear = true })
vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    -- Automatically captures and saves sidebar width between 18 and 60 columns
  end,
})
```

### Filtering & Hidden Files
Hidden files (dotfiles) and gitignored files are set to be visible by default:

```lua
filtered_items = {
    visible = true,
    hide_dotfiles = false,
    hide_gitignored = false,
}
```

To hide dotfiles or gitignored files by default, edit those values to `true` inside [`lua/plugins/editor/neo-tree.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/neo-tree.lua).

---

## 📁 2. Floating Desktop Explorer (Pure Lua Telescope)

The Floating Desktop Explorer is a 100% native Lua file browser powered by Telescope. It allows browsing files, creating/renaming/deleting files, and changing the Active Project Root (CWD).

### Keybindings & Commands
- **Shortcut:** `<Ctrl+Shift+F>` / `<Ctrl+Shift+f>`
- **Vim Command:** `:TelescopeFileBrowserDesktop`

### Explorer Controls
- `<Enter>`: Drill into folder OR open file in main editor buffer.
- `o`, `O`, or `<C-o>`: **Set selected folder as Active Project Root (CWD)** and save to recent projects history.
- `a` (or `<C-a>` in insert mode): **Create new file or folder**. (Append `/` at the end of the name to create a directory, e.g. `src/`).
- `r`: **Rename** selected file/folder.
- `d`: **Delete** selected file/folder (prompts for confirmation).
- `h` or `<BS>`: Navigate up to parent directory.
- `l`: Drill down into selected folder.
- `?` or `<F1>`: Show contextual help popup.

---

## ⚙️ Customizing Default Paths & Behavior

To change the default starting location for the Floating Explorer (currently user Desktop / OneDrive Desktop), modify `get_desktop_path()` in [`lua/config/krs/file_explorer.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/krs/file_explorer.lua):

```lua
function M.get_desktop_path()
    local home = vim.fn.expand("~")
    -- Modify return path as desired (e.g., home .. "/Projects")
    return home .. "/Desktop"
end
```
