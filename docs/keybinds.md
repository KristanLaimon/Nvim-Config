# ⌨️ Keyboard Shortcuts & Keybinds Reference

This document provides a comprehensive cheatsheet of all keyboard shortcuts in KRS Neovim, categorized by domain.

---

## 🛠️ General Editor & Clipboard (VSCode Style)

| Shortcut | Mode | Action | Description |
| :--- | :---: | :--- | :--- |
| `<C-s>` | Normal, Insert, Visual | Save File | Writes buffer to disk (`:w`) |
| `<C-c>` | Visual | Copy | Copy selection to system clipboard (`"+y`) |
| `<C-v>` | Normal, Visual, Insert | Paste | Paste from system clipboard (`"+p` / `<C-r>+`) |
| `<C-z>` | Normal, Visual, Insert | Undo | Undo last edit |
| `<C-y>` / `<C-S-z>` | Normal, Insert | Redo | Redo previous change |

---

## 💬 Code Commenting (US Standard & US-International Support)

*`Ctrl + ;` is non-dead on US-International layout and works seamlessly across all layouts.*

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-;>` / `<C-'>` / `<C-S-;>` / `<C-S-'>` | Normal, Insert | Toggle line comment (`gcc`) |
| `<C-;>` / `<C-'>` / `<C-S-;>` / `<C-S-'>` | Visual | Toggle selection comment (`gc`) |
| `<C-;>` / `<C-'>` / `<C-S-;>` / `<C-S-'>` | Terminal | Exits insert mode and comments code line |


---

## 🪟 Window Splits, Resizing & Buffer Navigation

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-h>` / `<C-l>` | Normal | Move cursor to left / right window split |
| `<C-Left>` / `<C-Right>` | Normal | Resize window width (narrower / wider) |
| `<C-Up>` / `<C-Down>` | Normal | Resize window height (taller / shorter) |
| `<C-S-h>` / `<C-S-j>` / `<C-S-k>` / `<C-S-l>` | Normal, Insert, Visual | Find file and open in Split (Left / Down / Up / Right) |
| `<A-h>` / `<A-Left>` | Normal | Cycle to Previous Buffer |
| `<A-l>` / `<A-Right>` | Normal | Cycle to Next Buffer |

---

## 💡 LSP, Diagnostics & Code Intellisense

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `K` | Normal | Show Hover Documentation |
| `<C-j>` | Normal, Insert, Visual | Trigger Signature & Parameter Help |
| `<A-k>` / `<M-k>` / `<leader>k` | Normal, Insert, Visual | Open Diagnostic Floating Window |
| `<leader>u` / `<leader>o` | Normal | Previous / Next Diagnostic Error |
| `<C-.>` | Normal, Insert, Visual | VSCode Quick Fix / Code Actions (Dropdown at Caret) |
| `<A-j>` / `<M-j>` / `<C-S-d>` | Normal, Insert, Visual | Go to Symbol Definition (with Telescope fallback) |
| `<F2>` | Normal | LSP / File Rename using floating `input_modal` component |
| `<leader>ff` | Normal, Visual | Format file or selection with `conform` |

---

## 🖥️ Terminal & Task Runner Shortcuts

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<Alt + 1..9>` | Normal, Insert, Terminal | Select & switch to terminal buffer #1..9 |
| `<Ctrl + ;>` | Normal, Insert, Terminal | Toggle open/hidden for currently selected terminal |
| `<C-S-t>` | Normal, Insert, Visual | Open Per-Project Task Menu (Telescope) |
| `<C-S-a>` | Normal, Insert, Visual | Run Default Task or Open Task Menu |
| `<C-1..4>` | Normal, Insert, Visual, Terminal | Toggle Background Task Output Slot #1..4 |
| `<C-`>` / `<C-S-o>` | Normal, Insert, Visual, Terminal | Toggle Last Active Task Output Window |
| `<C-v>` / `<C-S-v>` | Terminal, Insert, Normal | Paste OS clipboard into Terminal |
| `<C-c>` / `<C-S-c>` | Visual (Terminal & Buffers) | Copy selected text to OS clipboard |
| `:TaskRestart` / `<C-S-p>` | All | Kill & Restart active project task |
| `<C-LeftMouse>` | All | Open URL under cursor in web browser |

---

## 🐙 Git Control Center & Workspaces

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-S-g>` / `<C-S-G>` | All | Toggle Git Control Center |
| `s` / `S` | Git Center | Stage Selected File / Stage All Files |
| `u` / `U` | Git Center | Unstage Selected File / Unstage All Files |
| `r` | Git Center | Discard changes / Restore single file under cursor (with confirmation) |
| `R` | Git Center | Discard changes / Restore entire section (staged or unstaged) |
| `P` | Git Center | Push to Remote (with confirmation and remote branch selector) |
| `c` / `m` / `t` | Git Center | Edit Commit Title / Description / Tag via `input_modal` |
| `C` | Git Center | Execute Commit & Tag |
| `<C-S-w>` | All | Open Workspaces & Sessions Manager |
| `<C-S-m>` | All | Return to Main Menu (Alpha Dashboard) |

---

## 📁 File Explorer & Neo-tree Shortcuts

| Shortcut | Context | Action |
| :--- | :---: | :--- |
| `<C-S-Space>` / `<leader>e` | Normal | Toggle Neo-tree Sidebar |
| `<C-S-f>` | All | Open Desktop Floating File Explorer |
| `<leader>fw` | All | Open WSL Floating File Explorer |
| `<C-S-o>` | All | Open Folder Picker |
| `r` | Neo-tree | Rename file/folder via `input_modal` |
| `m` | Neo-tree | Move file/folder via Floating File Explorer (`root_dir` + `O` to confirm) |
| `a` / `A` / `<C-n>` / `<C-S-n>` | Neo-tree | Create new file or folder via `input_modal` |
| `<C-/>` / `<C-_>` | Neo-tree, Normal, Insert | Find files respecting `.gitignore` |
| `<C-S-/>` / `<C-?>` | Neo-tree, Normal, Insert | Find all files ignoring `.gitignore` |
