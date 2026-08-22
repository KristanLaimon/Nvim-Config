-- ============================================================================
-- KRS PYTHON: Centralized Python Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard PEP 8 4-space indentation defaults for Python buffers when no
--   .editorconfig file specifies buffer settings. Also owns the pyright LSP
--   server, the debugpy DAP adapter, and the `python` launch-profile runtime.
-- ============================================================================

local M = {}

--- The lspconfig/mason server name(s) this language owns.
M.lsp_server = { "pyright" }

--- lspconfig server settings, keyed by server name (see M.lsp_server).
---@type table<string, vim.lsp.Config>
M.lsp_config = {
	pyright = {},
}

--- Prefers the project's virtualenv interpreter over whatever `python` resolves
--- to on PATH, so imports match what the project actually installed.
--- @return string
local function python_path()
	local cwd = vim.fn.getcwd()
	for _, candidate in ipairs({
		"/venv/Scripts/python.exe",
		"/.venv/Scripts/python.exe",
		"/venv/bin/python",
		"/.venv/bin/python",
	}) do
		if vim.fn.executable(cwd .. candidate) == 1 then
			return cwd .. candidate
		end
	end
	return "python"
end

--- Filetypes the DAP configurations below attach to.
M.dap_filetypes = { "python" }

--- Static nvim-dap configurations, appended by lua/plugins/editor/dap.lua.
M.dap_configs = {
	{
		type = "python",
		request = "launch",
		name = "Launch Current File (Python)",
		program = "${file}",
		cwd = "${workspaceFolder}",
		console = "integratedTerminal",
		pythonPath = python_path,
	},
}

--- Mason package metadata, keyed by tool name.
M.mason = {
	pyright = { mason = "pyright", lang = "Python", type = "lsp", cmd = "pyright-langserver" },
	debugpy = { mason = "debugpy", lang = "Python Debugger", type = "dap", cmd = "debugpy-adapter" },
}

M.mason_order = { "pyright", "debugpy" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🐍 Python"
M.requires = {
	{ cmd = "python3", name = "Python 3", alt = "python", hint = "https://python.org" },
}
M.treesitter = { "python" }

--- Launch-profile runtimes this language owns (see lua/krs/launch/runtimes.lua).
M.launch_runtimes = {
	python = {
		command = "python",
		dap = function(profile, root, ctx)
			return {
				type = "python",
				request = "launch",
				name = profile.name,
				program = ctx.full_entry,
				cwd = root,
				console = "integratedTerminal",
			}
		end,
	},
}

--- Standard PEP 8 defaults for Python (4 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 4,
	autoindent = true,
}

--- Apply Python language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Python language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "python" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
