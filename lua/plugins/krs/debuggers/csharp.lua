-- ============================================================================
-- 🎯 C# / .NET — netcoredbg (coreclr)
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

return function(dap)
	shared.add(dap, { "cs" }, {
		{
			type = "coreclr",
			request = "launch",
			name = "Launch DLL (C#)",
			program = function()
				return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
			end,
		},
	})
end
