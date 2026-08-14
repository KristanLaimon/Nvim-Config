-- ============================================================================
-- PLUGIN: nvim-autopairs -- closes brackets, quotes and tags as you type.
-- ============================================================================
-- `check_ts` uses Treesitter to decide whether a pair really should close, so it
-- does not add a quote inside a string or a comment. Disabled in the telescope
-- prompt, where a stray closing bracket breaks the search pattern.
--
-- The completion menu is deliberately suppressed inside a freshly inserted empty
-- pair -- see the blink.cmp `auto_show` rule in lua/plugins/lsp/lsp.lua.
-- ============================================================================

return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		require("nvim-autopairs").setup({
			check_ts = true,
			disable_filetype = { "TelescopePrompt", "vim" },
		})
	end,
}
