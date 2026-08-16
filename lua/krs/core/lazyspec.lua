-- ============================================================================
-- krs.core.lazyspec -- Unique lazy.nvim `dir` for each local KRS plugin spec.
-- ============================================================================
-- WHY THIS EXISTS
--   lazy.nvim indexes local specs by their directory (lua/lazy/core/meta.lua,
--   `self.str_to_meta[fragment.dir]`), so every spec declaring the SAME `dir` is
--   merged into one plugin: the last `name` wins and only one `config()` ever runs.
--
--   Every module in lua/plugins/krs once declared the same directory, so all but
--   one were silently dropped -- no error, no warning, `config()` simply never ran
--   (which is why breakpoints were neither saved nor restored). Handing each spec
--   its own real, empty directory keeps them distinct.
--
-- USAGE -- call from inside the spec table itself, so the caller is your module:
--   return {
--     dir = require("krs.core.lazyspec").for_module(),
--     name = "krs-tasks",
--     config = function() ... end,
--   }
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

--- Parent directory holding one empty marker directory per local spec.
M.specs_root = vim.fn.stdpath("data") .. "/krs-specs"

--- In-memory cache of verified directories to avoid redundant disk I/O.
local created_dirs = {}

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Returns a directory unique to the calling file, creating it when missing.
--- Must be called directly from the spec table so `debug.getinfo(2)` resolves to
--- the plugin module, not to a wrapper function.
---
--- @return string dir Absolute path to this module's marker directory.
function M.for_module()
	local source = debug.getinfo(2, "S").source:sub(2)
	local mod_name = vim.fn.fnamemodify(source, ":t:r")
	local dir = M.specs_root .. "/" .. mod_name
	if not created_dirs[mod_name] then
		created_dirs[mod_name] = true
		local uv = vim.uv or vim.loop
		if not uv.fs_stat(dir) then
			uv.fs_mkdir(dir, 448)
		end
	end
	return dir
end

return M
