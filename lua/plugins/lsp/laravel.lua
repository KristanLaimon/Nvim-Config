-- ============================================================================
-- PLUGINS: PHP & Laravel support.
-- ============================================================================
-- 1. vim-blade      Syntax highlighting for `.blade.php` templates.
-- 2. blade-nav      Jump to and complete Blade components and routes.
-- 3. krs_php_tools  Registers `:PHPCheckTools`, which reports whether PHP and
--                   Composer are actually installed (on Windows or in WSL) and
--                   how to install what is missing.
--
-- The heavy lifting -- intelephense, pint formatting, the blade filetype pattern
-- -- lives in lsp.lua and formatting.lua.
-- ============================================================================

return {
	-- Blade filetype syntax highlighting
	{
		"jwalton512/vim-blade",
		ft = { "blade" },
	},

	-- Laravel Blade component navigation & completion
	{
		"ricardoramirezr/blade-nav.nvim",
		dependencies = {
			"saghen/blink.cmp",
		},
		ft = { "blade", "php" },
		opts = {
			close_tag_on_complete = true,
		},
	},

	-- PHP & Laravel Environment Check Modal Hook
	{
		name = "krs_php_tools",
		dir = vim.fn.stdpath("config") .. "/lua/plugins/krs",
		ft = { "php", "blade" },
		cmd = "PHPCheckTools",
		config = function()
			local modal = require("plugins.krs.php_tools_modal")

			vim.api.nvim_create_user_command("PHPCheckTools", function()
				modal.check_tools(false)
			end, { desc = "Check PHP & Laravel CLI environment status" })

			local checked = false
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "php", "blade" },
				callback = function()
					if not checked then
						checked = true
						-- Defer slightly to allow buffer layout to settle
						vim.defer_fn(function()
							modal.check_tools(false)
						end, 300)
					end
				end,
			})
		end,
	},
}
