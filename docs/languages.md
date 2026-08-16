# 🛠️ Languages, LSP, Formatters & Parsers

[← Back to Wiki Index](index.md)

Mason, `mason-lspconfig`, `mason-conform` and `mason-nvim-dap` install everything below on first start — no manual `:MasonInstall`.

Config files: `lua/plugins/lsp/lsp.lua` (servers + completion), `lua/plugins/lsp/formatting.lua` (Conform), `lua/plugins/lsp/treesitter.lua` (parsers), `lua/plugins/editor/dap.lua` (debug adapters).

---

## 📋 Matrix

| Language / Environment | LSP server | Formatter (Conform) | Treesitter parser | Debug adapter |
|---|---|---|---|---|
| **Lua** | `lua_ls` | `stylua` | `lua` | — |
| **JSON** | `jsonls` *(SchemaStore + local schemas)* | `prettierd` → `prettier` → `biome` | `json` | — |
| **JavaScript / TS / React** | `tsgo` | `prettierd` → `prettier` → `biome` | `typescript`, `javascript`, `tsx`, `jsx` | `js-debug-adapter` (`pwa-node`), Bun adapter |
| **HTML / CSS** | `html`, `cssls`, `emmet_ls`, `tailwindcss` | `prettierd` → `prettier` → `biome` | `html`, `css` | browser adapters |
| **Svelte** | `svelte` | `prettierd` → `prettier` → `biome` | `svelte` | browser adapters |
| **Astro** | `astro` | `prettier` (always) | `astro` | browser adapters |
| **Go** | `gopls` | `goimports`, `gofumpt` | `go`, `gomod`, `gowork`, `gosum` | `delve` (via `nvim-dap-go`) |
| **Python** | — (debug only) | — | `python` | `debugpy` |
| **PHP / Blade** | `intelephense` | `pint` → `php_cs_fixer`; Blade uses `blade-formatter` → `pint` | `php`, `phpdoc`, `blade` | `php-debug-adapter` (Xdebug) |
| **C# / `.csproj`** | `omnisharp` (`.cs`), `lemminx` (`.csproj`, `.props`, `.targets` as XML) | — | — | `netcoredbg` (`coreclr`) |
| **Docker** | `dockerls` | `dockerfmt` | — | — |
| **YAML / TOML** | `yamlls`, `taplo` | — | `yaml`, `toml` | — |
| **Linting (JS/TS)** | `eslint`, `biome` | — | — | — |
| **Markdown / editorconfig** | — | — | `markdown`, `markdown_inline`, `editorconfig` | — |
| **Vim / config** | — | — | `vim`, `vimdoc` | — |

---

## 🧠 Server notes

**TypeScript runs on `tsgo`, not `ts_ls`.** The Mason handler skips `vtsls` / `ts_ls` / `tsserver`, the main enable loop skips them too, and an `LspAttach` autocmd stops any of them that still manages to attach — so exactly one TS server is ever live. `tsgo` also gets a custom `root_dir` (nvim 0.11+ `(bufnr, on_dir)` signature, which must *call* `on_dir`): it roots at `tsconfig.json` / `jsconfig.json` / `package.json` / `.krsnvim` / `.nvimkrs`, and falls back to the file's own directory when the only match would be `$HOME` — otherwise opening a stray script indexes the whole home directory. Automatic type acquisition is off; types come from the [Type Injector](type-injector.md) instead.

**Diagnostics are native.** `tsgo` advertises `diagnosticProvider`, so Neovim pulls and refreshes diagnostics itself. An earlier hand-rolled fetch into a private namespace froze whatever the server knew a few hundred ms after attach — usually before `node_modules` was indexed — and never refreshed.

**PHP** — `intelephense` with a large stub set and `maxSize = 1000000`. `pint` and `php_cs_fixer` are conditional formatters: they only run when the binary is on `PATH` **or** `vendor/bin/pint(.bat)` / `vendor/bin/php-cs-fixer(.bat)` exists upward from the file. `.blade.php` is remapped to the `blade` filetype. `:PHPCheckTools` reports which PHP tools are missing on the host and inside WSL, with install steps.

**Astro and biome** — biome cannot format `.astro` templates at all, so those files are pinned to `prettier` (the project needs `prettier-plugin-astro` installed). Everywhere else the chain is `prettierd` → `prettier` → `biome`, `stop_after_first`.

**Mason has its own spec** (`cmd = "Mason"`) so `:Mason` exists on an empty Neovim. Pulled in only as an `nvim-lspconfig` dependency, its `setup()` runs on `BufReadPre` — no file open, no `:Mason`, which is exactly the state you're in when opening the dashboard on a fresh install.

**Format on save** via `conform.nvim` (`timeout_ms = 1000`, `lsp_fallback = true`). Manual: `<leader>ff` for the file or the visual selection.

**Schemas** — `schemastore.nvim` for `package.json`, `tsconfig.json`, `.eslintrc`… plus the local catalogs documented in [JSON Schemas](schemas-json.md) and [TOML Schemas](schemas-toml.md).

---

## ➕ Adding a Treesitter parser

`nvim-treesitter` is pinned to the `main` branch (the rewrite), which dropped `highlight.enable`. Highlighting is started per-buffer by a `FileType` autocmd calling `vim.treesitter.start()`, wrapped in `pcall` — parser names don't always match filetype names (`tsx` → `typescriptreact`, `vimdoc` → `help`), so the autocmd matches every filetype and lets `pcall` skip the ones with no parser.

1. Add the parser name to the `parsers` list at the top of `lua/plugins/lsp/treesitter.lua`.
2. `:TSUpdate`, or restart (`ts.install(parsers)` runs on setup).

No autocmd or pattern edits needed. For a full new language (server + formatter + parser), see [Adding a Language / LSP](adding-language.md).

---

## ⚡ Completion (blink.cmp)

`blink.cmp` replaces `nvim-cmp`. Two behaviours are deliberately tuned:

**Completion is off entirely** in the `krsinputmodal` filetype (so the [input modal](input-modal.md) stays a plain text field) and in any buffer setting `vim.b.completion = false`.

**The menu does not auto-open inside a freshly inserted empty pair** — right after autopairs turns `{` into `{}`, `[` into `[]`, `(` into `()`. This used to be a hard `enabled = false`, which also killed `<C-space>`: you couldn't ask for completion inside `import { | }`, which is the one place you always want it. Now only `menu.auto_show` is suppressed:

```lua
completion = {
  menu = {
    auto_show = function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local before, after = line:sub(col, col), line:sub(col + 1, col + 1)
      local pairs_map = { ["{"] = "}", ["["] = "]", ["("] = ")" }
      return pairs_map[before] ~= after
    end,
  },
  documentation = { auto_show = false },
}
```

Documentation is opt-in (`<C-space>`), and `{` / `[` are excluded from trigger characters so bracket-pair snippets don't fire on every keystroke.

### Custom completion sources

| Source | Fires in | Offers |
|---|---|---|
| [`krs.lsp.dap_repl_source`](debug-adapters.md#36-repl-completion-immediate-window) | `dap-repl`, only while a session is live | Real variables from the stopped frame, via the adapter's `completions` / `scopes` requests |
| [`plugins.krs.launch_cmp`](launch-profiles.md#-intellisense-inside-launchjson) | Any file named `launch.json` | Discovered project tasks for `pre_launch_tasks`, runtimes for `runtime`, `run`/`debug` for `mode` |
