-- ============================================================================
-- KRS BASH: Centralized Shell & Bash Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets Google Shell Style 2-space indentation defaults for Shell & Bash buffers
--   when no .editorconfig file specifies buffer settings. Also owns the bashls LSP
--   server and the beautysh formatter: settings, Mason names, filetypes.
-- ============================================================================

local M = {}

--- The lspconfig/mason server name(s) this language owns.
M.lsp_server = { "bashls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server).
M.lsp_config = {
	bashls = {
		filetypes = { "sh", "bash", "zsh", "csh", "ksh" },
	},
}

--- Mason package metadata, keyed by lspconfig/formatter name.
M.mason = {
	bashls = { mason = "bash-language-server", lang = "Bash / Shell", type = "lsp", cmd = "bash-language-server" },
	beautysh = { mason = "beautysh", name = "beautysh", type = "formatter", cmd = "beautysh" },
	["bash-debug-adapter"] = {
		mason = "bash-debug-adapter",
		lang = "Bash Debugger (bashdb)",
		type = "dap",
		cmd = "bash-debug-adapter",
	},
}

M.mason_order = { "bashls", "beautysh", "bash-debug-adapter" }

--- conform.nvim formatter list per filetype.
M.formatters_by_ft = {
	sh = { "beautysh" },
	bash = { "beautysh" },
	zsh = { "beautysh" },
	csh = { "beautysh" },
	ksh = { "beautysh" },
}

--- Registers the bashdb DAP adapter and its launch configuration. A function
--- (not plain `dap_configs`) because the `type` field depends on whether the
--- bashdb adapter actually registered -- that's only known once mason-nvim-dap
--- has had a chance to run first, which lua/plugins/editor/dap.lua guarantees.
--- @param dap table The `dap` module.
function M.dap_setup(dap)
	local mason_path = (vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter"):gsub("\\", "/")
	local bashdb_dir = mason_path .. "/extension/bashdb_dir"

	if not dap.adapters.bashdb and not dap.adapters.bash then
		local cmd_bin = mason_path .. "/bash-debug-adapter"
		if vim.fn.has("win32") == 1 then
			cmd_bin = mason_path .. "/bash-debug-adapter.cmd"
		end
		dap.adapters.bashdb = {
			type = "executable",
			command = cmd_bin,
			name = "bashdb",
		}
	end

	local adapter_type = dap.adapters.bashdb and "bashdb" or "bash"

	require("plugins.krs.debuggers._shared").add(dap, M.lsp_config.bashls.filetypes, {
		{
			type = adapter_type,
			request = "launch",
			name = "Launch Current File (Bash)",
			showDebugOutput = true,
			pathBashdb = bashdb_dir .. "/bashdb",
			pathBashdbLib = bashdb_dir,
			trace = true,
			file = "${file}",
			program = "${file}",
			cwd = "${workspaceFolder}",
			pathCat = "cat",
			pathBash = "bash",
			pathMkfifo = "mkfifo",
			pathPkill = "pkill",
			args = {},
			env = {},
			terminalKind = "integrated",
		},
	})
end

--- Standard Google Shell Style defaults for Bash / Shell (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply Bash language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Bash language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "sh", "bash", "zsh" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
