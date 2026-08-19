-- ============================================================================
-- 🎯 C# / .NET — netcoredbg (coreclr)
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

return function(dap)
	shared.add(dap, { "cs" }, {
		{
			type = "coreclr",
			request = "launch",
			name = "🎯 Launch .NET Assembly DLL (C#)",
			program = function()
				local root = vim.fn.getcwd()
				local dlls = vim.fn.glob(root .. "/bin/Debug/**/*.dll", false, true)
				if #dlls == 1 then
					return dlls[1]
				elseif #dlls > 1 then
					return vim.fn.input("Path to assembly DLL: ", dlls[1], "file")
				end
				return vim.fn.input("Path to assembly DLL: ", root .. "/bin/Debug/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopAtEntry = false,
		},
		{
			type = "coreclr",
			request = "launch",
			name = "🌐 Launch & Debug Blazor Server App",
			program = function()
				local root = vim.fn.getcwd()
				local dlls = vim.fn.glob(root .. "/bin/Debug/**/*.dll", false, true)
				for _, dll in ipairs(dlls) do
					if not dll:match("%.Views%.dll$") and not dll:match("%.resources%.dll$") then
						return dll
					end
				end
				return vim.fn.input("Path to Blazor app DLL: ", root .. "/bin/Debug/", "file")
			end,
			cwd = "${workspaceFolder}",
			env = {
				ASPNETCORE_ENVIRONMENT = "Development",
			},
			stopAtEntry = false,
		},
		{
			type = "coreclr",
			request = "attach",
			name = "🔌 Attach to Running .NET / Blazor Process",
			processId = function()
				return require("dap.utils").pick_process()
			end,
		},
	})
end
