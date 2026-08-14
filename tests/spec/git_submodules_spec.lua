-- ============================================================================
-- tests/spec/git_submodules_spec.lua -- Submodule parsing, discovery and listing.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local submodules = require("krs.git.submodules")

describe("git submodules parse_submodules", function()
	it("parses submodule status lines with various status prefixes", function()
		local lines = {
			" 68b5a03bf18274a2b130e9d57a91176b91176b91 lua/plugins/foo (v1.0.0)",
			"+1234567890abcdef1234567890abcdef12345678 themes/bar",
			"-abcdef1234567890abcdef1234567890abcdef12 libs/baz",
			"U9999999999999999999999999999999999999999 core/qux (heads/main)",
		}

		local parsed = submodules.parse_submodules(lines)
		expect(parsed).toEqual({
			"lua/plugins/foo",
			"themes/bar",
			"libs/baz",
			"core/qux",
		})
	end)

	it("parses git config format for .gitmodules", function()
		local lines = {
			"submodule.libA.path deps/libA",
			"submodule.libB.path deps/libB",
		}

		local parsed = submodules.parse_submodules(lines)
		expect(parsed).toEqual({
			"deps/libA",
			"deps/libB",
		})
	end)

	it("handles empty or malformed lines gracefully", function()
		local lines = {
			"",
			"   ",
			"fatal: not a git repository",
		}

		local parsed = submodules.parse_submodules(lines)
		expect(parsed).toEqual({})
	end)

	it("deduplicates repeated submodule paths", function()
		local lines = {
			" 1111111111111111111111111111111111111111 plugins/foo",
			"+2222222222222222222222222222222222222222 plugins/foo",
		}

		local parsed = submodules.parse_submodules(lines)
		expect(parsed).toEqual({ "plugins/foo" })
	end)
end)

describe("git submodules list", function()
	it("returns root repo as first entry", function()
		local list = submodules.list("C:/dev/my-project")
		expect(#list >= 1).toBeTruthy()
		expect(list[1].is_root).toBe(true)
		expect(list[1].path).toBe(".")
		expect(list[1].name).toBe("📦 my-project (Root)")
		expect(list[1].full_path).toBe("C:/dev/my-project")
	end)
end)

