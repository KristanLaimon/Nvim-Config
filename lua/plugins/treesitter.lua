return {
    'nvim-treesitter/nvim-treesitter',
    build = ":TSUpdate",
    config = function()
	local configs = require("nvim-treesitter.configs")
	configs.setup({
	    highlight = {
		enable = true,
	    },
	    indent = { enable = true },
	    autotage = { enable = true },
	    ensure_installed = {
		"lua",
		"teal",

		"astro",
		"svelte",
		"typescript",
		"javascript",
		"html",
		"css",
		"vim",

		"sql",

		"c_sharp",
		"go",

		"bash",
		"powershell"
	    },
	    auto_install = false
	})
    end
}
