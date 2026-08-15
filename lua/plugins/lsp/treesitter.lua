-- ============================================================================
-- PLUGIN: nvim-treesitter -- syntax trees for highlighting and text objects.
-- ============================================================================
-- ADD A LANGUAGE by adding its parser to the list below; `:TSUpdate` installs it.
-- The `.krsnvim` filetype has no parser of its own: it is registered as an alias
-- of Lua in lua/config/options.lua.
--
-- NOTE ON THE `main` BRANCH
--   It dropped the old `highlight.enable` option, so highlighting is started per
--   buffer by the autocmd at the bottom. Parser names do not always match
--   filetype names (tsx -> typescriptreact, vimdoc -> help), which is why it
--   matches every filetype and lets pcall skip the ones with no parser.
-- ============================================================================

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
	"jsx",
	"svelte",
	"astro",
	"html",
	"css",

	-- Backend / Data
	"bash",
	"go",
	"gomod",
	"gowork",
	"gosum",
	"json",
	"yaml",
	"toml",
	"editorconfig",
	"php",
	"phpdoc",
	"blade",
	"proto",
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
