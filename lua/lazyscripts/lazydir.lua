-- ============================================================================
-- 🦊 KRS: unique lazy.nvim `dir` per local plugin spec
-- ============================================================================
-- lazy.nvim indexes local specs by their directory (lua/lazy/core/meta.lua:79,
-- `self.str_to_meta[fragment.dir]`), so every spec declaring the same `dir` is
-- merged into ONE plugin: the last `name` wins and only one `config()` ever runs.
--
-- Every module in lua/plugins/krs declared the same directory, so all but one were
-- silently dropped — no error, no warning, just setup() never running (which is why
-- breakpoints were neither saved nor restored). Handing each spec its own empty,
-- real directory keeps them distinct.
-- ============================================================================

local M = {}

-- Call from the spec table itself: `dir = require("lazyscripts.lazydir").for_module()`.
-- The directory is named after the calling file, so it is unique per module.
function M.for_module()
	local source = debug.getinfo(2, "S").source:sub(2)
	local dir = vim.fn.stdpath("data") .. "/krs-specs/" .. vim.fn.fnamemodify(source, ":t:r")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	return dir
end

return M
