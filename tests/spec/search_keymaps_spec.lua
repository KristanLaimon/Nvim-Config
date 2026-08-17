-- ============================================================================
-- tests/spec/search_keymaps_spec.lua -- Unit tests for search keymappings.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect

describe("search keymaps configuration", function()
	it("configures <C-k>, <C-K>, <C-A-k> and <C-A-K> for find_all_files (ignoring .gitignore)", function()
		local search = require("config.keymaps.search")
		local find_all = search.settings.keys.find_all_files

		local has_ck, has_ck_upper = false, false
		local has_cak, has_cak_upper = false, false
		for _, key in ipairs(find_all) do
			if key == "<C-k>" then has_ck = true end
			if key == "<C-K>" then has_ck_upper = true end
			if key == "<C-A-k>" then has_cak = true end
			if key == "<C-A-K>" then has_cak_upper = true end
		end

		expect(has_ck).toBe(true)
		expect(has_ck_upper).toBe(true)
		expect(has_cak).toBe(true)
		expect(has_cak_upper).toBe(true)
	end)
end)
