# 🎓 How-To & Configuration Guide: Extending & Customizing KrsVim

[← Back to Wiki Index](index.md)

This comprehensive guide teaches you how to extend, customize, and maintain your **KrsVim** Neovim setup. It is written with easy-to-follow examples for every part of the configuration so you can add new plugins, languages, themes, terminals, or custom modules with complete confidence.

---

## 📂 File Structure & Directory Layout Explanation

```
c:\Users\Kristan\AppData\Local\nvim\
├── init.lua                   -- Main Neovim bootstrap file (loads lua/config/lazy.lua)
├── colors/                    -- Colorscheme files in nagatoro-krs palette format (*-krs.lua & nagatoro-*.lua)
├── docs/                      -- Full offline documentation & Wiki files
├── lua/
│   ├── config/                -- Core editor bootstrap & global options
│   │   ├── options.lua        -- Vim options, filetypes, path resolution
│   │   ├── lazy.lua           -- Lazy.nvim plugin manager bootstrap
│   │   └── keymaps/           -- Global keybindings (lsp.lua, editor.lua, search.lua, debug.lua, krs.lua)
│   ├── krs/                   -- Shared pure Lua libraries (NO keymaps/autocmds, 100% unit-testable)
│   │   ├── core/              -- Store (JSON persistence), Path, Project, UI floats, Z-Index stack
│   │   ├── git/               -- Git command wrappers, porcelain parsers, diff formatters
│   │   ├── launch/            -- Launch profile runtimes & DAP resolvers
│   │   ├── lsp/               -- CodeAction menu, Colorify completion engine, EditorConfig
│   │   └── projects/          -- Starred favorites manager
│   └── plugins/               -- Lazy.nvim plugin specifications
│       ├── editor/            -- Third-party editor plugins (Neo-tree, Telescope, DAP, Auto-pairs)
│       ├── lsp/               -- LSP servers, Mason, Blink.cmp, Conform formatting, Treesitter
│       ├── ui/                -- Dashboard, Bufferline, Statusline, Devicons, Themes
│       ├── miscelanea/        -- Utility plugins
│       └── krs/               -- Custom local KRS modules (each a self-contained Lazy spec)
├── tests/                     -- Unit & integration test suite (`tests/run.lua`)
└── .krsnvim/                  -- Per-project persistent state (tasks.json, launch.json, breakpoints.json)
```

---

## 🎓 1. How to Add a New Third-Party Plugin (Lazy.nvim)

All external plugins are managed via `lazy.nvim`. To add a new plugin:

1. Choose the appropriate subdirectory in `lua/plugins/`:
   - `lua/plugins/editor/` for editor features (pickers, motions, tree-sitter tools).
   - `lua/plugins/ui/` for visual components.
   - `lua/plugins/lsp/` for language tooling.
   - `lua/plugins/miscelanea/` for utility tools.

2. Create a new `.lua` file (e.g., `lua/plugins/editor/mini_surround.lua`):
```lua
-- ============================================================================
-- PLUGINS: Mini.surround -- Fast surround manipulation (add, delete, change quotes/brackets).
-- ============================================================================

return {
    "echasnovski/mini.surround",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        mappings = {
            add = "sa", -- Add surrounding in Normal and Visual modes
            delete = "sd", -- Delete surrounding
            find = "sf", -- Find surrounding (to the right)
            replace = "sr", -- Replace surrounding
        },
    },
}
```

3. Save the file. Next time you start Neovim (or run `:Lazy`), `lazy.nvim` automatically installs and configures the plugin!

---

## 🔌 2. How to Create a Local KRS Module or `.krslocal` Feature

Custom features in KrsVim live in `lua/plugins/krs/*.lua`. Every file directly inside `lua/plugins/krs/` returns a dual spec-module metatable that auto-registers with `lazy.nvim`.

### Step-by-Step Example (`lua/plugins/krs/my_helper.lua`):

```lua
-- ============================================================================
-- KRS PLUGIN: My Helper -- Custom local module.
-- ============================================================================

local store = require("krs.core.store")

local M = {}

-- 1. Put all tunable options in M.settings (NEVER M.config or M.opts!)
M.settings = {
    greeting = "Hello from local module!",
    keymap = "<leader>mh",
}

function M.say_hello()
    vim.notify(M.settings.greeting, vim.log.levels.INFO, { title = "My Helper" })
end

function M.setup()
    vim.api.nvim_create_user_command("MyHelperRun", M.say_hello, { desc = "Run My Helper" })
    vim.keymap.set("n", M.settings.keymap, M.say_hello, { desc = "Run My Helper" })
end

M.setup()

-- 2. Return dual spec-module metatable
local plugin_spec = {
    name = "krs_my_helper",
    dir = require("krs.core.lazyspec").for_module(),
    lazy = false,
    config = M.setup,
}

return setmetatable(plugin_spec, { __index = M })
```

---

## 🌐 3. How to Add a New Language (LSP, Treesitter, Formatter, Debugger)

To add full IDE support for a new programming language (e.g., Elixir, Zig, Scala, Kotlin, Ruby):

1. **Mason LSP Server (`lua/plugins/lsp/lsp.lua`)**:
   Add the language server to `ensure_installed` and `servers`:
   ```lua
   ensure_installed = { "lua_ls", "vtsls", "gopls", "zls" }, -- e.g. Add "zls" for Zig
   servers = {
       zls = {}, -- Options for zls
   }
   ```

2. **Treesitter Syntax Highlighting (`lua/plugins/lsp/treesitter.lua`)**:
   Add the language parser to `ensure_installed`:
   ```lua
   ensure_installed = { "lua", "typescript", "go", "zig" },
   ```

3. **Conform Code Formatter (`lua/plugins/lsp/formatting.lua`)**:
   Add the formatter for the filetype:
   ```lua
   formatters_by_ft = {
       zig = { "zigfmt" },
   }
   ```

4. **Debug Adapter (DAP) (`lua/plugins/editor/dap.lua` & `lua/krs/launch/runtimes.lua`)**:
   Register DAP adapter configuration in `lua/plugins/editor/dap.lua` and launch command in `runtimes.lua`.

---

## 🖥️ 4. How to Customize Terminals & Dock

KrsVim includes a multi-terminal manager supporting 9 independent floating/docked terminal buffers.

- **Toggle Terminal**: `<C-;>`
- **Switch Slots**: `<A-1>` .. `<A-9>`
- **Config file**: `lua/plugins/krs/terminals.lua`
- **Default Shell**: Automatically detects WSL `wsl.exe` on Windows, or `pwsh.exe` / `bash`. You can set your preferred shell in `lua/config/options.lua`:
  ```lua
  vim.opt.shell = "pwsh"
  ```

---

## 🎨 5. How to Customize Statusline & Themes

### Statusline Themes:
Run `:KrsStatuslineTheme` or select from Command Palette (`<C-Shift-P>`) to switch between:
- `nvchad_pills` (NvChad rounded pills)
- `nvchad_blocks` (NvChad block separators)
- `nagatoro_classic` (Classic Nagatoro statusline)
- `vscode` (Flat VSCode style)
- `minimal` (Compact)

### Editor Themes in `colors/*.lua`:
To create a new theme matching `nagatoro-krs` format, copy `colors/nagatoro-krs.lua` to `colors/mytheme-krs.lua`, change `vim.g.colors_name = "mytheme-krs"`, and edit the palette table `p`:
```lua
local p = {
    bg = "#1a1b26",
    bg_dark = "#16161e",
    fg = "#a9b1d6",
    func = "#7aa2f7",
    keyword = "#bb9af7",
    -- ...
}
```
Run `:KrsThemePicker` or `<leader>th` to switch themes live with interactive preview!

---

## 🛠️ 6. How to Add Build Tasks & Launch Profiles

Per-project build tasks and debugging launch profiles live in `.krsnvim/` inside your project root:

- **`.krsnvim/tasks.json`** (Build & script runner):
  ```json
  {
    "custom_tasks": [
      {
        "name": "Build Production",
        "cmd": "npm run build",
        "is_default": true
      }
    ]
  }
  ```
  Press `<C-S-t>` to open the Task Runner menu.

- **`.krsnvim/launch.json`** (Debugging profiles):
  ```json
  {
    "version": "0.2.0",
    "configurations": [
      {
        "type": "node",
        "request": "launch",
        "name": "Launch App",
        "program": "${workspaceFolder}/src/index.ts"
      }
    ]
  }
  ```
  Press `<C-S-q>` to open Launch Profiles Manager or `<C-S-s>` to start debugging.

---

## ⚙️ 7. Installation, Dependencies & Requirements

### System Requirements:
- **Neovim**: v0.9.0 or higher (v0.10+ recommended).
- **Git**: Required for plugin downloading & Git Center.
- **CLI Utilities**:
  - `ripgrep` (`rg`) for fast searching (`<C-Shift-F>`).
  - `fd` for fast file finding.
  - C Compiler (`gcc`, `clang`, or `zig`) for Treesitter parser compilation.

### Automated Setup Scripts:
- **Windows**: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`
- **Linux / WSL**: `./setup.sh`

*(If external tools are missing, KrsVim degrades gracefully with clear notifications instead of crashing).*
