return {
	{
		"NeogitOrg/neogit",
		branch = "master",
		cmd = "Neogit",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			local neogit = require("neogit")
			neogit.setup({
				kind = "vsplit",
				graph_style = "ascii",
				integrations = {
					diffview = true,
					telescope = true,
				},
			})
		end,
	},
}
