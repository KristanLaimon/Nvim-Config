-- ============================================================================
-- KRS GO: Centralized Go Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard `gofmt` hard-tab indentation defaults (tabs, width 4) for Go buffers
--   when no .editorconfig file specifies buffer settings. Also owns the gopls LSP
--   server and the gofumpt/goimports formatters: settings, Mason names, filetypes.
-- ============================================================================

local M = {}

--- The lspconfig/mason server name(s) this language owns.
M.lsp_server = { "gopls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server).
M.lsp_config = {
	gopls = {
		settings = {
			gopls = {
				codelenses = {
					gc_details = false,
					generate = true,
					regenerate_cgo = true,
					run_govulncheck = true,
					test = true,
					tidy = true,
					upgrade_dependency = true,
					vendor = true,
				},
				hints = {
					assignVariableTypes = true,
					compositeLiteralFields = true,
					compositeLiteralTypes = true,
					constantValues = true,
					functionTypeParameters = true,
					parameterNames = true,
					rangeVariableTypes = true,
				},
				analyses = {
					unusedparams = true,
					shadow = true,
				},
				staticcheck = true,
				gofumpt = true,
			},
		},
	},
}

--- Mason package metadata, keyed by lspconfig/formatter name.
M.mason = {
	gopls = { mason = "gopls", lang = "Go", type = "lsp", cmd = "gopls" },
	gofumpt = { mason = "gofumpt", name = "gofumpt", type = "formatter", cmd = "gofumpt" },
	goimports = { mason = "goimports", name = "goimports", type = "formatter", cmd = "goimports" },
}

M.mason_order = { "gopls", "gofumpt", "goimports" }

--- conform.nvim formatter list per filetype.
M.formatters_by_ft = {
	go = { "goimports", "gofumpt" },
}

--- delve is installed via mason-nvim-dap (nvim-dap-go's own concern), not Mason
--- directly, so it has no `M.mason` entry -- kept here only for documentation.
M.dap_tool = "delve"

--- nvim-dap-go registers the adapter and the standard configurations (debug
--- file, debug test, attach) itself, so there is nothing to add by hand here.
--- @param _ table The `dap` module (unused: dap-go talks to nvim-dap directly).
function M.dap_setup(_)
	local ok, dap_go = pcall(require, "dap-go")
	if ok then
		dap_go.setup()
	end
end

--- Launch-profile runtimes this language owns (see lua/krs/launch/runtimes.lua).
M.launch_runtimes = {
	go = {
		command = "go run",
		dap = function(profile, root, ctx)
			return {
				type = "go",
				request = "launch",
				name = profile.name,
				mode = "debug",
				program = ctx.full_entry,
				cwd = root,
			}
		end,
	},
}

--- Standard `gofmt` defaults for Go (hard tabs, width 4).
M.defaults = {
	expandtab = false,
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 0,
	autoindent = true,
}

--- Apply Go language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Go language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "go", "gomod", "gowork" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
