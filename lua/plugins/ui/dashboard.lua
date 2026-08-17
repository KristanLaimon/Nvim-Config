-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local settings = {
	--- Colour of the ASCII banner. Re-applied on every colorscheme change.
	header_highlight = { name = "AlphaHeaderOrange", opts = { fg = "#FF8800", bold = true } },

	--- Menu entries, in order: { key, icon, label, command }.
	buttons = {
		{ "f", "", "File Explorer (Desktop)", ":TelescopeFileBrowserDesktop<CR>" },
		{ "p", "", "Recent projects", ":Telescope projects<CR>" },
		{ "w", "", "Wiki (Documentation)", ":KrsWiki<CR>" },
		{ "e", "", "Plugins/Extensions", ":Lazy<CR>" },
		{ "m", "", "Lsps/Languages", ":Mason<CR>" },
		{ "q", "", "Quit", ":qa<CR>" },
	},

	--- WSL entry, inserted at this position when WSL is available.
	wsl_button = { "l", "", "File Explorer (WSL)", ":TelescopeFileBrowserWSL<CR>" },
	wsl_button_position = 4,

	--- Filetypes that must never be replaced by the dashboard.
	protected_filetypes = { "alpha", "neo-tree" },
}

return {
	"goolord/alpha-nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		dashboard.section.header.val = {
			[[             /\     /\                                                     /\  /\								   ]],
			[[            ( ..   .. )                                                   ( .. ..)							  ]],
			[[             \ Y  /                                                        \ Y  /								  ]],
			[[          /\_/\   /\_/\    _  __ ____  ____   _   _ _   _ ___ __  __     /\_/\/\_/\					      ]],
			[[         (   o o     o o  | |/ /|  _ \/ ___| | \ | | | | |_ _|  \/  |   (o o   o o)								]],
			[[          \   ~   ~   /   | ' / | |_) \___ \ |  \| | | | || || |\/| |    \   ~  ~ /								]],
			[[           \___^___/      | . \ |  _ < ___) || |\  | |_| || || |  | |     \___^__/							  ]],
			[[                          |_|\_\|_| \_\____/ |_| \_|\___/|___|_|  |_|                             ]],
			[[           /\_/\                                                              /\_/\               ]],
			[[          ( -.- )~                                                           ~( -.- )             ]],
			[[          (____)__)                                                          (____)__)            ]],
			[[           |  | |           "Foxes can be coders too!" - Random fox             |  | |            ]],
			[[           |  | |                                                             |  | |              ]],
			[[           /\_/\                                                              /\_/\               ]],
			[[          ( >.< )                        (>.<)                               ( >.< )              ]],
			[[           ^---^                                                              ^---^               ]],
		}

		-- `:colorscheme` clears user-defined groups, so the banner colour is
		-- re-applied whenever the theme changes.
		local function set_header_highlight()
			vim.api.nvim_set_hl(0, settings.header_highlight.name, settings.header_highlight.opts)
		end
		set_header_highlight()
		vim.api.nvim_create_autocmd("ColorScheme", { callback = set_header_highlight })
		dashboard.section.header.opts.hl = settings.header_highlight.name

		--- Turns a settings entry into an alpha button.
		--- @param entry table `{ key, icon, label, command }`
		local function make_button(entry)
			return dashboard.button(entry[1], entry[2] .. "  " .. entry[3], entry[4])
		end

		dashboard.section.buttons.val = vim.tbl_map(make_button, settings.buttons)

		-- The WSL entry would be a dead end on a machine without WSL.
		local ok_wsl, wsl = pcall(require, "plugins.krs.wsl")
		if ok_wsl and wsl.available() then
			table.insert(dashboard.section.buttons.val, settings.wsl_button_position, make_button(settings.wsl_button))
		end

		dashboard.section.footer.val = ""

		-- alpha redraws on WinResized, which fires while a window is already gone
		-- (closing a split or the explorer) and then throws "invalid window id".
		-- Wrapping both entry points keeps that out of the message history.
		for _, name in ipairs({ "redraw", "draw" }) do
			local original = alpha[name]
			alpha[name] = function(...)
				return pcall(original, ...)
			end
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

					-- Focus is in a terminal or a panel: leave it alone.
					if buftype == "terminal" or vim.tbl_contains(settings.protected_filetypes, filetype) then
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
