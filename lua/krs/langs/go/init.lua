-- ============================================================================
-- KRS GO: Centralized Go Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard `gofmt` hard-tab indentation defaults (tabs, width 4) for Go buffers
--   when no .editorconfig file specifies buffer settings.
-- ============================================================================

local M = {}

--- Standard `gofmt` defaults for Go (hard tabs, width 4).
M.defaults = {
	expandtab = false,
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 0,
	autoindent = true,
}

--- Apply Go language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Go language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "go", "gomod", "gowork" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
