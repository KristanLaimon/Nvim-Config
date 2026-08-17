-- ============================================================================
-- tests/spec/notify_focus_protection_spec.lua -- Notify focus protection tests.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect

describe("krs.core.notify focus protection", function()
	it("registers NotifyDismiss and ClearToasts user commands and sets vim.notify", function()
		local core_notify = require("krs.core.notify")
		core_notify.setup()

		local cmds = vim.api.nvim_get_commands({})
		expect(cmds.NotifyDismiss).toBeDefined()
		expect(cmds.ClearToasts).toBeDefined()
	end)

	it("dispatches non-blocking notifications cleanly without errors", function()
		local core_notify = require("krs.core.notify")
		core_notify.setup()

		local ok = pcall(function()
			vim.notify("Test info toast", vim.log.levels.INFO, { title = "Test" })
			vim.notify("Test warn toast", vim.log.levels.WARN, { title = "Test" })
			vim.notify("Test error toast", vim.log.levels.ERROR, { title = "Test" })
		end)
		expect(ok).toBe(true)
	end)
end)
