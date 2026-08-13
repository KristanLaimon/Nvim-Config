-- ============================================================================
-- 🦊 KRS PLUGIN: Floating Toast Notifications (nvim-notify)
-- ============================================================================
-- Replaces native Neovim cmdline `:echo` notifications with floating toast windows
-- that appear in the top-right / top-left corner and auto-hide after 3 seconds.
-- ============================================================================

return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		opts = {
			stages = "fade_in_slide_out",
			timeout = 3000, -- Auto-hide after 3 seconds (3000ms)
			top_down = true,
			render = "compact",
			fps = 60,
			max_width = 80,
			max_height = 10,
		},
		config = function(_, opts)
			local ok, notify = pcall(require, "notify")
			if ok then
				notify.setup(opts)
				vim.notify = notify
			end
		end,
	},
}
