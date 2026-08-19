-- ============================================================================
-- 🐘 PHP — Xdebug (php-debug-adapter)
-- ============================================================================
-- Xdebug connects to the editor, not the other way round: nvim listens on 9003
-- and the request being debugged attaches to it.
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

return function(dap)
	shared.add(dap, { "php", "blade" }, {
		{
			type = "php",
			request = "launch",
			name = "🐘 Listen for Xdebug (Vanilla PHP / Laravel Web / Herd)",
			port = 9003,
			stopOnEntry = false,
			log = false,
			pathMappings = {
				["${workspaceFolder}"] = "${workspaceFolder}",
			},
		},
		{
			type = "php",
			request = "launch",
			name = "📄 Launch Current Script (Vanilla PHP CLI)",
			program = "${file}",
			cwd = "${fileDirname}",
			port = 9003,
			runtimeArgs = { "-dxdebug.mode=debug", "-dxdebug.start_with_request=yes" },
		},
		{
			type = "php",
			request = "launch",
			name = "🚀 Debug Laravel Artisan Command",
			program = "${workspaceFolder}/artisan",
			cwd = "${workspaceFolder}",
			args = function()
				local cmd = vim.fn.input("Artisan command args (e.g. migrate, queue:work): ")
				if cmd == "" then
					return {}
				end
				return vim.split(cmd, "%s+")
			end,
			port = 9003,
			runtimeArgs = { "-dxdebug.mode=debug", "-dxdebug.start_with_request=yes" },
		},
		{
			type = "php",
			request = "launch",
			name = "🌐 Debug Laravel App (artisan serve)",
			program = "${workspaceFolder}/artisan",
			args = { "serve" },
			cwd = "${workspaceFolder}",
			port = 9003,
			runtimeArgs = { "-dxdebug.mode=debug", "-dxdebug.start_with_request=yes" },
		},
	})
end
