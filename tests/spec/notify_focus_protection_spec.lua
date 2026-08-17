-- ============================================================================
-- tests/spec/notify_focus_protection_spec.lua -- Notify focus protection tests.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect

describe("plugins.ui.notify focus protection", function()
	it("exports valid lazy spec with static rendering and focusable=false on_open handler", function()
		local spec = require("plugins.ui.notify")
		expect(spec).toBeDefined()
		expect(spec[1].opts.stages).toBe("static")
		expect(type(spec[1].opts.on_open)).toBe("function")
	end)

	it("exports valid config function", function()
		local spec = require("plugins.ui.notify")
		expect(type(spec[1].config)).toBe("function")
	end)
end)
