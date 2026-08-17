-- ============================================================================
-- PLUGIN: nvim-notify -- floating toast notifications.
-- ============================================================================
-- Replaces `vim.notify`, so every message in this config (task results, git
-- output, launch errors) appears as a toast in the corner instead of a cmdline
-- echo that scrolls away. Loaded eagerly and with high priority, because modules
-- start notifying during startup.
--
-- Mobile/Termux Protection:
--   * `stages = "static"` prevents high-frequency 60fps animation loops from
--     stalling mobile CPU/touch input dispatchers.
--   * `on_open` enforces `focusable = false` so notification floats NEVER grab
--     input focus or freeze keyboard/touch inputs.
--   * Autocmd automatically jumps back to main editor window if focus ever
--     lands in a notification buffer window.
-- ============================================================================

return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		opts = {
			stages = "static", -- Static display: no heavy 60fps animation timers stalling mobile input
			timeout = 2500, -- Auto-hide after 2.5 seconds (2500ms)
			top_down = true,
			render = "compact",
			fps = 1,
			max_width = 70,
			max_height = 8,
			on_open = function(win)
				-- Ensure notification window can NEVER steal focus or freeze input
				pcall(vim.api.nvim_win_set_config, win, { focusable = false })
				local buf = vim.api.nvim_win_get_buf(win)
				vim.keymap.set("n", "<Esc>", function()
					pcall(require("notify").dismiss, { silent = true })
				end, { buffer = buf, silent = true })
			end,
		},
		config = function(_, opts)
			local ok, notify = pcall(require, "notify")
			if ok then
				notify.setup(opts)
				vim.notify = notify

				-- Autocmd: If focus ever accidentally lands in a notify window, restore main window instantly
				vim.api.nvim_create_autocmd("FileType", {
					pattern = "notify",
					callback = function(args)
						local win = vim.fn.bufwinid(args.buf)
						if win and win ~= -1 then
							pcall(vim.api.nvim_win_set_config, win, { focusable = false })
							if vim.api.nvim_get_current_win() == win then
								vim.schedule(function()
									vim.cmd("wincmd p")
								end)
							end
						end
					end,
				})

				-- User commands to dismiss all notifications
				vim.api.nvim_create_user_command("NotifyDismiss", function()
					notify.dismiss({ silent = true })
				end, { desc = "Dismiss all floating toast notifications" })

				vim.api.nvim_create_user_command("ClearToasts", function()
					notify.dismiss({ silent = true })
				end, { desc = "Dismiss all floating toast notifications" })

				-- Quick keymap to clear toasts
				vim.keymap.set("n", "<leader>nd", function()
					notify.dismiss({ silent = true })
				end, { desc = "Dismiss active notifications" })

				vim.keymap.set("n", "<leader>un", function()
					notify.dismiss({ silent = true })
				end, { desc = "Dismiss active notifications" })
			end
		end,
	},
}
