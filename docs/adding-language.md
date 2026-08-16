# 🌐 Adding a New Language / LSP to Neovim Config

[← Back to Wiki Index](index.md)

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
To enable auto-formatting on save or via `<leader>ff`, open [`lua/plugins/lsp/formatting.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/formatting.lua) and add the filetype to `formatters_by_ft`:

```lua
formatters_by_ft = {
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    svelte = { "prettierd", "prettier", stop_after_first = true },
    astro = { "prettierd", "prettier", stop_after_first = true },
    python = { "isort", "black", stop_after_first = true },
}
```

> ⚠️ **Astro is a special case.** `biome` cannot format `.astro` template markup at all (silent no-op), so `astro` is hardcoded to `{ "prettier" }` only — no `biome`/`prettierd`, and no project `.prettierrc` required (the `prettier` formatter's `condition` bypasses the rc-file check just for `ctx.filetype == "astro"`). It also always passes `--plugin prettier-plugin-astro`, which must be installed as a devDependency in every Astro project (`bun add -D prettier prettier-plugin-astro`) — otherwise prettier still fails to parse `.astro` files.
>
> To customize astro's prettier options (tabWidth, quotes, etc.) without turning `biome`-formatted filetypes (ts/js/css/svelte/...) onto prettier project-wide, don't add a generic `.prettierrc` — add `.prettierrc.astro.json` instead. Only astro's `args` function looks for that filename; every other filetype's `condition` only recognizes the standard `.prettierrc*` names, so they stay on `biome`.

---

### Step 4.5: (Optional) Add a Linter

There is **no `nvim-lint`** in this config. Diagnostics come from LSP servers only, so a linter is added exactly like Step 2 + Step 3 — as a server in [`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua):

```lua
opts = {
    servers = {
        eslint = {},   -- JS/TS linting
        biome = {},    -- JS/TS/JSON/CSS lint + format
        ruff = {},     -- Python linting
    },
}

require("mason-lspconfig").setup({
    ensure_installed = { "eslint", "biome", "ruff" },
})
```

Most linters ship a language server (`eslint`, `biome`, `ruff`, `golangci_lint_ls`, `phpstan` via `intelephense`, ...) — install it in `:Mason` and register it, nothing else needed. The linter picks up the project's own config file (`eslint.config.js`, `biome.json`, `ruff.toml`); no per-project setup here.

> ⚠️ Two linters on the same filetype means duplicate diagnostics. `eslint` and `biome` are both registered here — that's fine only because each one no-ops when its config file is absent from the project. Don't add a third JS linter.

If a linter has **no** language server (e.g. `shellcheck` alone, `markdownlint`), it can't be wired up through this config as-is; `mfussenegger/nvim-lint` would have to be added first.

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
| **Linting** | [`lua/plugins/lsp/lsp.lua`](file:///C:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua) | Add linter's LSP to `opts.servers` (no `nvim-lint`) |
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
