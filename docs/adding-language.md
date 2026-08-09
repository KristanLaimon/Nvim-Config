# 🌐 Adding a New Language / LSP to Neovim Config

This guide outlines the exact step-by-step procedure for adding new programming language support, Language Servers (LSPs), Treesitter syntax highlighting, and auto-formatters to this Neovim setup.

---

## 🛠️ Step-by-Step Guide

### Step 1: Install the LSP in Mason
Run the Mason package manager command inside Neovim:
```vim
:Mason
```
Search for and install the required Language Server (e.g., `svelte-language-server`, `astro-language-server`, `typescript-language-server`, `pyright`, `gopls`).

> ℹ️ **Note**: Installing an LSP via Mason downloads the binary to disk (`stdpath("data")/mason/bin/`), but Neovim will **not** automatically enable or attach it to buffers until Step 2 is completed.

---

### Step 2: Enable the Server in `lua/plugins/lsp/lsp.lua`
Open [`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua) and register the `nvim-lspconfig` server name under `opts.servers`:

```lua
opts = {
    servers = {
        -- Existing servers
        lua_ls = { ... },
        jsonls = {},

        -- Add new servers here:
        ts_ls = {},     -- TypeScript / JavaScript
        svelte = {},    -- Svelte
        astro = {},     -- Astro
        pyright = {},   -- Python
    },
}
```

> ⚠️ **Why is this step required?**  
> The config iterates over `opts.servers` using `for server, config in pairs(opts.servers) do` and executes `vim.lsp.enable(server)`. If a server is missing from `opts.servers`, Neovim will never attach the LSP to open buffers even if it is installed in Mason.

---

### Step 3: (Recommended) Add to `ensure_installed` in `mason-lspconfig`
In the same file ([`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua)), add the LSP server name to `mason-lspconfig` setup:

```lua
require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "jsonls",
        "ts_ls",
        "svelte",
        "astro",
        "pyright",
    },
})
```

> 💡 **Benefit**: When syncing or migrating your Neovim config to another machine, Mason will automatically download and install these servers in the background without needing to manually run `:Mason`.

---

### Step 4: (Optional) Configure Auto-Formatting in `lua/plugins/lsp/formatting.lua`
To enable auto-formatting on save or via `<leader>f`, open [`lua/plugins/lsp/formatting.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/formatting.lua) and add the filetype to `formatters_by_ft`:

```lua
formatters_by_ft = {
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    svelte = { "prettierd", "prettier", stop_after_first = true },
    astro = { "prettierd", "prettier", stop_after_first = true },
    python = { "isort", "black", stop_after_first = true },
}
```

---

### Step 5: (Optional) Configure Treesitter Syntax Highlighting in `lua/plugins/lsp/treesitter.lua`
Open [`lua/plugins/lsp/treesitter.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/treesitter.lua) and add the parser name to `ensure_installed`:

```lua
ensure_installed = {
    "lua",
    "typescript",
    "javascript",
    "svelte",
    "astro",
    "python",
}
```

---

## ⚡ Quick Checklist for New Languages

| Component | File to Edit | Key Section |
|---|---|---|
| **LSP Server Activation** | [`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua) | Add to `opts.servers` |
| **Auto-Installation** | [`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua) | Add to `mason-lspconfig` `ensure_installed` |
| **Formatting** | [`lua/plugins/lsp/formatting.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/formatting.lua) | Add to `formatters_by_ft` |
| **Syntax Highlighting** | [`lua/plugins/lsp/treesitter.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/treesitter.lua) | Add to `ensure_installed` |

---

## 🔍 Verification & Debugging

- Open a file of the target language and run:
  ```vim
  :LspInfo
  ```
  Ensure the expected language server appears under **Active client(s)**.
- For code completion, start typing or press `<C-space>` to open the `blink.cmp` completion menu.
