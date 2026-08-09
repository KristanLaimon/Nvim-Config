# Multi-Terminal Manager Configuration Guide

This guide explains how the Lazy-Loading Multi-Terminal Manager works and how to customize terminal count, keybindings, window dimensions, and terminal behaviors in this Neovim setup.

---

## 📁 Key File

- **Multi-Terminal Manager Module:** [`lua/config/krs/terminal.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/krs/terminal.lua)

---

## 🚀 Overview & Capabilities

The Multi-Terminal Manager allows managing up to **9 independent persistent terminal sessions** (Terminals #1 through #9) in Neovim.

### Key Highlights:
1. **Lazy Loading**: Terminals are only spawned when first accessed, preserving fast startup times.
2. **Persistence**: Terminal shell sessions remain alive in background buffers when toggled/hidden.
3. **Clean Focus Returning**: Remembering the code window you came from so closing a terminal restores your exact previous editing context.

---

## ⌨️ Keybindings & Controls

### 1. Selecting / Switching Terminal (#1 to #9)
- **Shortcut:** `<Alt+1>` through `<Alt+9>` (works in Normal, Insert, and Terminal mode).
- **Behavior:**
  - If a terminal window is already open split at the bottom, pressing `<Alt+N>` switches the visible buffer to Terminal #N instantly.
  - If no terminal split is open, it opens a bottom split displaying Terminal #N.

### 2. Toggling Current Terminal
- **Shortcut:** `<Ctrl+;>` (works in Normal, Insert, and Terminal mode).
- **Behavior:**
  - If the cursor is currently inside the active terminal window, pressing `<Ctrl+;>` hides the terminal window and restores focus to your code buffer.
  - If the terminal is open but lost focus, pressing `<Ctrl+;>` refocuses the terminal and starts Insert mode.
  - If the terminal is hidden, pressing `<Ctrl+;>` re-opens the bottom split for the currently selected terminal.

### 3. Window Navigation from Terminal
- **Shortcut:** `<Ctrl+w>` (e.g. `<Ctrl+w>h`, `<Ctrl+w>k`, `<Ctrl+w>w`) allows navigating out of terminal windows without quitting terminal insert mode manually.

---

## ⚙️ Customizing Split Height & Window Options

Terminal windows are created at the bottom of the editor using Neovim's split API inside `open_terminal(n)`:

```lua
-- lua/config/krs/terminal.lua snippet
-- Create bottom split window (10 lines high)
vim.cmd("botright 10split")
t.win = vim.api.nvim_get_current_win()

-- Visual window options for terminal
vim.wo[t.win].number = false
vim.wo[t.win].relativenumber = false
vim.wo[t.win].signcolumn = "no"
```

### Customizing Height
To change the default split height from 10 lines to something else (e.g., 15 lines or a percentage), modify `"botright 10split"` in [`lua/config/krs/terminal.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/krs/terminal.lua):

```lua
-- Example: Change to 15 lines height
vim.cmd("botright 15split")
```

---

## 🛠️ Changing Terminal Shell or Environment

By default, Neovim invokes the OS default shell (PowerShell on Windows, bash/zsh on Linux/macOS).

To enforce a specific shell executable (e.g., `cmd.exe` or `pwsh.exe`) across terminal instances, set `vim.o.shell` in [`lua/config/options.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/config/options.lua):

```lua
-- Example: Force pwsh.exe on Windows
if vim.fn.has("win32") == 1 then
    vim.o.shell = "pwsh.exe"
    vim.o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
end
```
