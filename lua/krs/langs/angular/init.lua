-- ============================================================================
-- KRS ANGULAR: Centralized Angular Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Owns the Angular Language Service (angularls) LSP server. cmd/probe-location
--   resolution (node_modules discovery, @angular/core version) is handled by
--   nvim-lspconfig's bundled default config for angularls -- nothing to override
--   here beyond root markers/filetypes.
-- ============================================================================

---@type KrsLangModule
local M = {}

--- The lspconfig/mason server name this language owns.
M.lsp_server = { "angularls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server).
---@type table<string, vim.lsp.Config>
M.lsp_config = {
	angularls = {},
}

--- Mason package metadata, keyed by lspconfig name. `cssls` is owned by
--- `lua/krs/langs/web/init.lua` (its `lsp_config`/settings apply regardless
--- of which bundle installs the package) -- listed again here only so the
--- Angular bundle can install it without requiring the separate Web Frontend
--- bundle for `.scss` diagnostics/completion.
M.mason = {
	angularls = { mason = "angular-language-server", lang = "Angular", type = "lsp", cmd = "ngserver" },
	cssls = { mason = "css-lsp", lang = "CSS", type = "lsp", cmd = "vscode-css-language-server" },
}

M.mason_order = { "angularls", "cssls" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🅰️ Angular"
M.requires = {
	{ cmd = "node", name = "Node.js", hint = "https://nodejs.org" },
}
M.treesitter = { "html", "scss" }

return M
