local parsers = {
	-- Core / Editor
	"lua",
	"vim",
	"vimdoc",
	"markdown",
	"markdown_inline",

	-- Frontend
	"typescript",
	"javascript",
	"tsx",
	"svelte",
	"astro",
	"html",
	"css",

	-- Backend / Data
	"go",
	"gomod",
	"gowork",
	"gosum",
	"json",
	"yaml",
	"toml",
	"editorconfig",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "TSUpdate", "TSInstall" },
	config = function()
		local ts = require("nvim-treesitter")
		ts.setup({})
		ts.install(parsers)

		-- main branch dropped the old highlight.enable config; highlighting
		-- must be started manually per buffer. Parser names don't always
		-- match filetype names (tsx -> typescriptreact, vimdoc -> help), so
		-- match any filetype and let pcall skip ones without a parser.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "*",
			callback = function()
				pcall(vim.treesitter.start)
			end,
		})
	end,
}
