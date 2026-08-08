return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	cmd = { "TSUpdate", "TSInstall", "TSBufEnable", "TSBufDisable", "TSEnable", "TSDisable" },
	config = function()
		local ok, ts = pcall(require, "nvim-treesitter.configs")
		if ok then
			ts.setup({
				ensure_installed = {
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
				},
				highlight = { enable = true },
				indent = { enable = true },
			})
		else
			local config = require("nvim-treesitter")
			if config and config.install then
				pcall(config.install, {
					"lua", "vim", "vimdoc", "markdown", "markdown_inline",
					"typescript", "javascript", "tsx", "svelte", "astro", "html", "css",
					"go", "gomod", "gowork", "gosum", "json", "yaml", "toml",
				})
			end
		end
	end,
}

