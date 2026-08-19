-- ============================================================================
-- KRS CSHARP: Centralized C# / .NET Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard Microsoft C# 4-space indentation defaults for C# buffers when no
--   .editorconfig file specifies buffer settings.
-- ============================================================================

local M = {}

--- Standard C# / .NET defaults (4 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 4,
	autoindent = true,
}

--- Apply C# language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize C# language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "cs" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
