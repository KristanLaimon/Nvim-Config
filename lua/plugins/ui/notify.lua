-- ============================================================================
-- PLUGIN: nvim-notify -- Beautiful floating toast notifications.
-- ============================================================================
-- Features:
--   * Original `rcarriga/nvim-notify` visual look, icons, highlights & borders.
--   * Native `fade_in_slide_out` stages: ease-in-out slide entry/exit & auto slide-UP.
--   * Mobile focus protection: `on_open` enforces `focusable = false` so toasts
--     NEVER steal keyboard/touch input or freeze Neovim.
--   * Autocmd instantly restores editor focus if cursor ever touches a notify buffer.
-- ============================================================================

return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		opts = {
			stages = "fade_in_slide_out", -- Original smooth ease-in-out slide & auto slide-UP
			timeout = 3000, -- Auto-hide after 3 seconds
			top_down = true,
			render = "default", -- Original beautiful render style with borders & icons
			fps = 30, -- Smooth 30fps animation
			max_width = 75,
			max_height = 10,
			background_colour = "Normal",
			on_open = function(win)
				-- Enforce focusable = false on every opened notification window
				pcall(vim.api.nvim_win_set_config, win, { focusable = false })
				local buf = vim.api.nvim_win_get_buf(win)
				if buf and vim.api.nvim_buf_is_valid(buf) then
					pcall(vim.api.nvim_buf_set_option, buf, "focusable", false)
				end
			end,
		},
		config = function(_, opts)
			local ok, notify = pcall(require, "notify")
			if ok then
				notify.setup(opts)
				vim.notify = notify

				-- Autocmd: If focus ever lands in a notify float, restore main editor window instantly
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
			else
				-- Fallback to krs.core.notify
				require("krs.core.notify").setup()
			end
		end,
	},
}
