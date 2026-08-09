return {
	{
		"doki-theme/doki-theme-vim",
		lazy = false, -- Ensures the theme loads immediately on startup
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			-- 'auto' inherits the palette and background directly from the active colorscheme
			theme = "auto",
		},
	},
}
