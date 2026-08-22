-- ============================================================================
-- KRS DOCKER & PROTO: Centralized Dockerfile & Protobuf Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard 2-space indentation defaults for Dockerfile and Protobuf buffers
--   when no .editorconfig file specifies buffer settings. Also owns the dockerls
--   and buf_ls (disabled) LSP servers, and the protolint formatter.
-- ============================================================================

---@type KrsLangModule
local M = {}

--- The lspconfig/mason server name(s) this language owns.
M.lsp_server = { "dockerls", "buf_ls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server). `buf_ls` is
--- disabled: nothing currently needs Buf's language server, kept here only so
--- enabling it is a one-line `enabled` flip.
---@type table<string, vim.lsp.Config>
M.lsp_config = {
	dockerls = {},
	buf_ls = { enabled = false },
}

--- Mason package metadata, keyed by lspconfig/formatter name. `dockerfmt` has none:
--- it is not Mason-installable in this setup, must be on PATH.
M.mason = {
	dockerls = { mason = "dockerfile-language-server", lang = "Docker", type = "lsp", cmd = "docker-langserver" },
	buf_ls = { mason = "buf", lang = "Protobuf (buf)", type = "lsp", cmd = "buf" },
	protolint = { mason = "protolint", name = "protolint", type = "formatter", cmd = "protolint" },
}

--- `buf_ls` is excluded from the Mason install order: it's disabled, so never
--- auto-installed.
M.mason_order = { "dockerls", "protolint" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🐳 Docker & Proto"
M.requires = {} -- dockerfile-language-server & protolint are standalone Mason binaries
M.treesitter = { "editorconfig", "proto" }

--- conform.nvim formatter list per filetype.
M.formatters_by_ft = {
	dockerfile = { "dockerfmt" },
	proto = { "protolint" },
}

--- Standard defaults for Dockerfile & Protobuf (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply Docker / Proto language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Dockerfile & Protobuf language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "dockerfile", "proto" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
