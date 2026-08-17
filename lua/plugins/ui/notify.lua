-- ============================================================================
-- PLUGIN: nvim-notify -- Bulletproof floating toast notifications.
-- ============================================================================
-- Uses `krs.core.notify` for zero-overhead, focus-safe, non-blocking toast
-- notifications that can NEVER steal keyboard/touch input or freeze Neovim.
-- ============================================================================

local core_notify = require("krs.core.notify")

return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		config = function()
			core_notify.setup()
		end,
	},
}
