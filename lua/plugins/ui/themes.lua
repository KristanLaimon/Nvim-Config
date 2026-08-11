return {
	{
		"doki-theme/doki-theme-vim",
		lazy = false, -- Ensures the theme loads immediately on startup
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
