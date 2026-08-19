-- ============================================================================
-- KRS BASH: Centralized Shell & Bash Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets Google Shell Style 2-space indentation defaults for Shell & Bash buffers
--   when no .editorconfig file specifies buffer settings.
-- ============================================================================

local M = {}

--- Standard Google Shell Style defaults for Bash / Shell (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply Bash language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Bash language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "sh", "bash", "zsh" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
