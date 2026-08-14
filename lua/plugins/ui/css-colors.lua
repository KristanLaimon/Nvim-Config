-- ============================================================================
-- PLUGIN: nvim-highlight-colors -- colour previews inside the code.
-- ============================================================================
-- Renders `#rrggbb`, `rgb()`, `hsl()` and Tailwind class colours with their actual
-- colour, in CSS and anywhere else a colour literal appears.
-- ============================================================================

return {
	"brenoprata10/nvim-highlight-colors",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("nvim-highlight-colors").setup({})
	end,
}
