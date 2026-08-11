-- ============================================================================
-- 🐍 Python — debugpy
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

-- Prefer the project's virtualenv interpreter over whatever `python` resolves
-- to on PATH, so imports match what the project actually installed.
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

return function(dap)
	shared.add(dap, { "python" }, {
		{
			type = "python",
			request = "launch",
			name = "Launch Current File (Python)",
			program = "${file}",
			cwd = "${workspaceFolder}",
			console = "integratedTerminal",
			pythonPath = python_path,
		},
	})
end
