-- ============================================================================
-- PLUGIN: nvim-notify -- floating toast notifications.
-- ============================================================================
-- Replaces `vim.notify`, so every message in this config (task results, git
-- output, launch errors) appears as a toast in the corner instead of a cmdline
-- echo that scrolls away. Loaded eagerly and with high priority, because modules
-- start notifying during startup.
--
-- Timing and size are the `opts` below; `timeout` is how long a toast stays.
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
