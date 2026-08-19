-- ============================================================================
-- KRS LANGS: Centralized Per-Language Configuration Manager
-- ============================================================================
-- WHAT IT DOES
--   Automatically imports and executes `setup()` for all per-language configuration
--   submodules under `lua/krs/langs/<lang>/init.lua`.
-- ============================================================================

local M = {}

--- Registered per-language configuration modules.
M.langs = {
	php = require("krs.langs.php"),
}

--- Initialize all per-language configuration submodules.
function M.setup()
	for _, lang in pairs(M.langs) do
		if type(lang) == "table" and type(lang.setup) == "function" then
			lang.setup()
		end
	end
end

return M
