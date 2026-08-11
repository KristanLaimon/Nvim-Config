-- ============================================================================
-- 🐘 PHP — Xdebug (php-debug-adapter)
-- ============================================================================
-- Xdebug connects to the editor, not the other way round: nvim listens on 9003
-- and the request being debugged attaches to it.
-- ============================================================================

local shared = require("plugins.krs.debuggers._shared")

return function(dap)
	shared.add(dap, { "php" }, {
		{
			type = "php",
			request = "launch",
			name = "Listen for Xdebug",
			port = 9003,
		},
	})
end
