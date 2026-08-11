# Color Palette & Theme Configuration Guide

This guide explains how to manage, customize, and extend colorschemes in this Neovim configuration.

---

## 📁 Key Files & Directories

- **Theme Plugin Specification:** [`lua/plugins/ui/themes.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/ui/themes.lua)
- **Live Colorscheme Previewer:** [`lua/plugins/krs/colorscheme_preview.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/colorscheme_preview.lua)

---

## 🎨 Core Color Palette Architecture

The UI color scheme is driven by:
1. **Installed Colorscheme Plugins**: Theme plugins (such as `doki-theme/doki-theme-vim`, `catppuccin/nvim`, `folke/tokyonight.nvim`).
2. **Dynamic Background Inheritance**: Colorschemes naturally control their background palette, syntax highlighting, popups, and statusline styles without hardcoded background overrides.

---

## 📦 How to Add or Change Themes

### 1. Adding a New Theme Plugin
To add a new theme, add its specification to the returned table in [`lua/plugins/ui/themes.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/ui/themes.lua):

```lua
return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("catppuccin-mocha")
        end,
    },
    -- ... other plugins
}
```

### 2. Statusline Integration (Lualine)
Lualine is configured with `theme = "auto"`, meaning it dynamically adapts its palette to match whichever colorscheme is active.

---

## 🦊 Live Colorscheme Previewer

The configuration includes an active live colorscheme preview module [`lua/plugins/krs/colorscheme_preview.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/colorscheme_preview.lua).

### How it Works:
1. Type `:colorscheme <theme>` in Command Mode and hit `<Tab>` to cycle through themes.
2. Neovim previews the theme and its background in real time as you scroll options.
3. If you press `<Esc>` (abort), it restores your previous colorscheme automatically without persisting changes.
4. Pressing `<Enter>` confirms and applies the selected theme.
