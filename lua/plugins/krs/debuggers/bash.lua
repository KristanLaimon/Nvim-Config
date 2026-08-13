-- ============================================================================
-- 🐚 Bash — bash-debug-adapter / bashdb
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

return function(dap)
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

	shared.add(dap, { "sh", "bash", "zsh", "csh", "ksh" }, {
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
