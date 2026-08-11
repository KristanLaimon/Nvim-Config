# 📁 File Explorers & Move Picker (`plugins.krs.file_explorer`)

KRS Neovim includes native floating file explorers for Desktop, WSL, folder picking, and moving files.

---

## ⚡ Features

1. **Desktop Explorer (`<C-S-f>`)**: Pure Lua floating file explorer starting at user Desktop or home directory.
2. **WSL Explorer (`<leader>fw`)**: Native WSL distribution filesystem explorer.
3. **Folder Picker (`<C-S-o>`)**: Interactive Telescope folder browser to switch active workspace CWD cleanly.
4. **Neo-tree Move File Picker (`m`)**: Pressing `m` on a file in Neo-tree opens the floating file explorer starting at project root (`getcwd()`). Navigate to target folder and press `O` to move file without renaming.
5. **Gitignore vs All Files Search in Neo-tree**:
   - `<C-/>` / `<C-_>`: Find files **respecting `.gitignore`**.
   - `<C-S-/>` / `<C-?>`: Find **all files ignoring `.gitignore`**.

---

## ⌨️ Explorer Shortcuts

- `<C-S-f>`: Open Desktop File Explorer
- `<leader>fw`: Open WSL File Explorer
- `<C-S-o>`: Open Folder Picker
- `m` (in Neo-tree): Move file/folder via floating picker
- `O` / `o` (in Move Picker): Confirm target folder to move file into
- `r` (in Neo-tree): Rename file/folder via `input_modal`
- `a` (in Neo-tree): Create new file or folder via `input_modal`
- `<C-/>`: Search files respecting `.gitignore`
- `<C-S-/>`: Search all files ignoring `.gitignore`
