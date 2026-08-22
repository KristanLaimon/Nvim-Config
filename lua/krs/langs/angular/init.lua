-- ============================================================================
-- KRS ANGULAR: Centralized Angular Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Owns the Angular Language Service (angularls) LSP server. cmd/probe-location
--   resolution (node_modules discovery, @angular/core version) is handled by
--   nvim-lspconfig's bundled default config for angularls -- nothing to override
--   here beyond root markers/filetypes.
-- ============================================================================

local M = {}

--- The lspconfig/mason server name this language owns.
M.lsp_server = { "angularls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server).
---@type table<string, vim.lsp.Config>
M.lsp_config = {
	angularls = {},
}

--- Mason package metadata, keyed by lspconfig name.
M.mason = {
	angularls = { mason = "angular-language-server", lang = "Angular", type = "lsp", cmd = "ngserver" },
}

M.mason_order = { "angularls" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🅰️ Angular"
M.requires = {
	{ cmd = "node", name = "Node.js", hint = "https://nodejs.org" },
}
M.treesitter = { "html", "scss" }

return M
