-- ============================================================================
-- tests/integration/keymap_collisions_spec.lua -- Fails on un-allowlisted
-- keymap collisions, including ones only created on VimEnter.
-- ============================================================================
-- WHY THIS LIVES HERE, NOT IN tests/spec
--   debug.lua rebinds toggle_enabled keys inside a VimEnter autocmd on
--   purpose (see debug.lua:163-193), so that collision only exists once the
--   event has actually fired. Neither `nvim -l tests/run.lua` (unit specs)
--   nor the `-c`/`-S` arguments this integration runner itself uses fire
--   VimEnter before quitting -- confirmed by checking `maparg("<A-h>", "n")`
--   after each: it stays "Previous buffer" (editor.lua) until VimEnter is
--   fired for real. So this spec fires it explicitly.
--
--   krs.core.keymap_registry keeps its own M.collisions log (not just a
--   fire-and-forget vim.notify) precisely so this spec can also see the
--   collisions that happened during the eager config.keymaps load, which
--   finishes before any spec file -- including this one -- gets to run.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect

describe("keymap collisions after a real startup", function()
	it("has no un-allowlisted mode+lhs collisions once VimEnter has fired", function()
		vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })

		local registry = require("krs.core.keymap_registry")
		local summary = {}
		for _, c in ipairs(registry.collisions) do
			table.insert(summary, string.format("%s (%s): %s <-> %s", c.lhs, c.mode, c.first_source, c.second_source))
		end

		expect(summary).toEqual({})
	end)
end)
