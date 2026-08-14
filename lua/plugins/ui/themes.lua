-- ============================================================================
-- PLUGINS: Theme and statusline.
-- ============================================================================
-- doki-theme-vim ships the upstream palettes; the active colorscheme is the local
-- `nagatoro-krs` in colors/, which is where every highlight is actually defined.
--
-- lualine renders the single global statusline (`laststatus = 3`): branch, diff
-- and diagnostics on the left, file name next, mode and position on the right.
-- ============================================================================

return {
	{
		"doki-theme/doki-theme-vim",
		-- Eager: a lazily loaded theme means a flash of the default colours.
		lazy = false,
		config = function()
			pcall(vim.cmd.colorscheme, "nagatoro-krs")
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			options = {
				theme = "auto",
				globalstatus = true,
			},
			sections = {
				lualine_a = {
					{
						"branch",
						icon = "🌿",
					},
					"diff",
					"diagnostics",
				},
				lualine_b = {
					{
						"filename",
						file_status = true,
						path = 1,
					},
				},
				lualine_c = {},
				lualine_x = {
					{
						"mode",
						fmt = function(str)
							return "-- " .. str .. " --"
						end,
					},
					"encoding",
					"fileformat",
					"filetype",
				},
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		},
	},
}
