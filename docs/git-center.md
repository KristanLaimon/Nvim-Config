# Git Center Configuration & Usage Guide

This guide explains how the interactive Git Control Center (`<Ctrl+Shift+G>`) works, its features, custom diff highlights, and how to configure or extend it.

---

## 📁 Key Files

- **Git Center Control Panel:** [`lua/plugins/krs/git_center.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/git_center.lua)
- **Neogit Integration Spec:** [`lua/plugins/editor/neogit.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/neogit.lua)

---

## 🚀 How to Launch Git Center

- **Shortcut:** Press `<Ctrl+Shift+G>` or `<Ctrl+Shift+g>` from any mode.
- **Vim Command:** `:GitCenter`

---

## 🖥️ Layout & Interface Overview

Git Center uses a dual-window split floating layout:

1. **Left Window (Control Panel)**: Displays repository status, current branch, lines added/deleted, commit form, staged files, unstaged/untracked files, and linear commit graph history.
2. **Right Window (VSCode Live Diff Preview)**: Live diff viewer featuring clean VSCode-style syntax highlighting for added (`+`) and deleted (`-`) lines, excluding noisy git CLI terminal headers.

---

## ⌨️ Controls & Keybindings Inside Git Center

### Section Jumping
- `1`: Jump cursor to **Section 1** (Commit Box & Tag)
- `2`: Jump cursor to **Section 2** (Staged Files)
- `3`: Jump cursor to **Section 3** (Unstaged & Untracked Files)
- `4`: Jump cursor to **Section 4** (Linear Commit Graph & Tags)

### Staging & Unstaging Files
- `s` (Normal Mode): Stage the file currently under the cursor.
- `s` (Visual Mode): Stage multiple selected files at once.
- `S` (Shift + s): Stage **all** modified and untracked files.
- `u` (Normal Mode): Unstage the file currently under the cursor.
- `u` (Visual Mode): Unstage multiple selected files at once.
- `U` (Shift + u): Unstage **all** staged files.

### Commit & Tagging Workflow
- `c`: Edit Commit Title (opens floating native editor modal).
- `m`: Edit Commit Description (optional detailed commit body).
- `t`: Edit Tag name (optional, e.g. `v1.0.0`).
- `C` (Shift + c): Execute `git commit` (and create tag if specified).

### Navigation & Preview Scrolling
- `<Tab>`: Toggle focus between Left Control Panel and Right Diff Preview window.
- `<Ctrl+Shift+J>` / `<Ctrl+J>`: Scroll down inside the Right Diff Preview window.
- `<Ctrl+Shift+K>` / `<Ctrl+K>`: Scroll up inside the Right Diff Preview window.
- `d`: Open full interactive file diff using `DiffviewOpen`.
- `r`: Refresh Git status in-place (Zero-flicker reload).
- `<Ctrl+Shift+G>`, `q`, or `<Esc>`: Close Git Center.

---

## 🎨 VSCode Diff Color Customization

Diff colors are defined in `setup_diff_highlights()` inside [`lua/plugins/krs/git_center.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/git_center.lua):

```lua
local function setup_diff_highlights()
    -- Added lines (+) -> Subtle green background, light green text
    vim.api.nvim_set_hl(0, "GitCenterDiffAdd", { bg = "#1c3427", fg = "#a6e3a1", default = true })
    
    -- Deleted lines (-) -> Subtle red background, light red text
    vim.api.nvim_set_hl(0, "GitCenterDiffDelete", { bg = "#3b1d22", fg = "#f38ba8", default = true })
    
    -- Diff Hunk Header (@@) -> Subtle blue background, cyan text
    vim.api.nvim_set_hl(0, "GitCenterDiffHeader", { bg = "#1e293b", fg = "#89dceb", bold = true, default = true })
    
    -- Unchanged context text
    vim.api.nvim_set_hl(0, "GitCenterDiffContext", { fg = "#cdd6f4", default = true })
end
```

To modify these colors, edit hex values for `bg` and `fg` in `setup_diff_highlights()`.

---

## 📐 Layout Window Dimensions

To adjust the size of the Git Center popups, edit `open_git_center()` in [`lua/plugins/krs/git_center.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/git_center.lua):

```lua
local total_width = math.floor(vim.o.columns * 0.92)  -- 92% screen width
local total_height = math.floor(vim.o.lines * 0.85)   -- 85% screen height
local left_width = math.floor(total_width * 0.50)     -- 50% left panel width
```
