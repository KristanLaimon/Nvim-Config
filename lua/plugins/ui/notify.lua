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
		opts = function()
			local is_mobile = false
			local env_ok, env_mod = pcall(require, "krs.core.environment")
			if env_ok then
				local env = env_mod.detect()
				is_mobile = env.is_mobile or env.is_termux or env.is_proot
			else
				is_mobile = vim.env.TERMUX_VERSION ~= nil or vim.fn.isdirectory("/data/data/com.termux") == 1
			end

			return {
				stages = is_mobile and "static" or "fade_in_slide_out",
				timeout = is_mobile and 2000 or 3000,
				top_down = true,
				render = "default",
				fps = is_mobile and 5 or 30,
				max_width = is_mobile and 45 or 75,
				max_height = is_mobile and 6 or 10,
				background_colour = "Normal",
				on_open = function(win)
					pcall(vim.api.nvim_win_set_config, win, { focusable = false })
				end,
			}
		end,
		config = function(_, opts)
			local ok, notify = pcall(require, "notify")
			if ok then
				local final_opts = type(opts) == "function" and opts() or opts
				notify.setup(final_opts)
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
