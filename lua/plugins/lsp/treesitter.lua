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

-- Minimal Core Parsers (Fresh Neovim default)
local core_parsers = {
	"lua",
	"vim",
	"vimdoc",
	"markdown",
	"markdown_inline",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local env_ok, env_mod = pcall(require, "krs.core.environment")
		local is_native_termux = false -- only true for bare Termux (Android, no proot)
		if env_ok then
			local env = env_mod.detect()
			-- proot Ubuntu is a full Linux container — treat it like desktop Linux.
			-- Only skip heavy installs on native Termux (no /etc/os-release distro).
			is_native_termux = env.is_termux and not env.is_proot
		else
			is_native_termux = vim.env.TERMUX_VERSION ~= nil
				and vim.fn.isdirectory("/data/data/com.termux") == 1
				and vim.fn.filereadable("/etc/os-release") == 0
		end

		local ts = require("nvim-treesitter")
		ts.setup({})
		if not is_native_termux then
			pcall(ts.install, core_parsers)
		end

		-- main branch dropped the old highlight.enable config; highlighting
		-- must be started manually per buffer. Parser names don't always
		-- match filetype names (tsx -> typescriptreact, vimdoc -> help), so
		-- match any filetype and let pcall skip ones without a parser.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "*",
			callback = function(args)
				local buf = args.buf
				pcall(vim.treesitter.start, buf)

				local ft = vim.bo[buf].filetype
				if ft and ft ~= "" then
					local lang = vim.treesitter.language.get_lang(ft) or ft
					local has_parser = pcall(vim.treesitter.get_parser, buf, lang)
					if has_parser then
						vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter.indent'.get_indent(v:lnum)"
					end
				end
				vim.bo[buf].autoindent = true
			end,
		})
	end,
}

