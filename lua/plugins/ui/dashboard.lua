return {
	"goolord/alpha-nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		dashboard.section.header.val = {
			[[																																															]],
			[[             /\     /\                                                    /\  /\							]],
			[[            ( ..   .. )                                                  ( .. ..)							]],
			[[             \ Y  /                                                       \ Y  /							]],
			[[          /\_/\   /\_/\    _  __ ____  ____   _____  _____   __     __     /\_/\/\_/\					]],
			[[         (   o o     o o   | |/ /|  _ \/ ___| |  __ \|  __ \  \ \   / /    (o o   o o)				]],
			[[          \   ~   ~   /    | ' / | |_) \___ \ | |  | | |  | |  \ \ / /     \   ~  ~ /					]],
			[[           \___^___/       | . \ |  _ < ___) || |  | | |  | |   \ V /       \___^__/					]],
			[[                           |_|\_\|_| \_\____/ |_|  |_|_|  |_|    \_/													]],
			[[																																						                 ]],
		}

		-- Orange highlight for header ASCII art
		local function set_header_hl()
			vim.api.nvim_set_hl(0, "AlphaHeaderOrange", { fg = "#FF8800", bold = true })
		end
		set_header_hl()
		vim.api.nvim_create_autocmd("ColorScheme", { callback = set_header_hl })
		dashboard.section.header.opts.hl = "AlphaHeaderOrange"

		dashboard.section.buttons.val = {
			dashboard.button("f", "  File Explorer (Desktop)", ":TelescopeFileBrowserDesktop<CR>"),
			dashboard.button("p", "  Recent projects", ":Telescope projects<CR>"),
			dashboard.button("e", "  Plugins/Extensions", ":Lazy<CR>"),
			dashboard.button("m", "  Lsps/Languages", ":Mason<CR>"),
			dashboard.button("q", "  Quit", ":qa<CR>"),
		}

		-- Only show the WSL folder button on Windows when WSL is actually installed
		local ok_wsl, wsl = pcall(require, "config.krs.wsl")
		if ok_wsl and wsl.available() then
			table.insert(
				dashboard.section.buttons.val,
				3,
				dashboard.button("w", "  File Explorer (WSL)", ":TelescopeFileBrowserWSL<CR>")
			)
		end

		dashboard.section.footer.val = ""

		-- Wrap alpha.redraw and alpha.draw in pcall to prevent WinResized invalid window id errors when closing splits/explorer
		local orig_redraw = alpha.redraw
		alpha.redraw = function(...)
			return pcall(orig_redraw, ...)
		end

		local orig_draw = alpha.draw
		alpha.draw = function(...)
			return pcall(orig_draw, ...)
		end

		alpha.setup(dashboard.opts)

		-- Closing the last real buffer shows the dashboard instead of quitting.
		vim.api.nvim_create_autocmd("BufDelete", {
			callback = function()
				vim.schedule(function()
					local win = vim.api.nvim_get_current_win()
					if not vim.api.nvim_win_is_valid(win) then
						return
					end
					local buf = vim.api.nvim_win_get_buf(win)
					local buftype = vim.bo[buf].buftype
					local filetype = vim.bo[buf].filetype

					-- Do not open dashboard if focused in terminal, neo-tree, or alpha
					if buftype == "terminal" or filetype == "alpha" or filetype == "neo-tree" then
						return
					end

					local listed = vim.tbl_filter(function(b)
						return vim.fn.buflisted(b) == 1 and vim.api.nvim_buf_get_name(b) ~= ""
					end, vim.api.nvim_list_bufs())

					if #listed == 0 then
						vim.cmd("Alpha")
					end
				end)
			end,
		})
	end,
}

