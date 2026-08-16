-- ============================================================================
-- tests/spec/wiki_modal_spec.lua -- Documentation Center Wiki Modal.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local wiki_modal = require("plugins.krs.wiki_modal")

describe("plugins.krs.wiki_modal", function()
	it("exposes documentation categories and docs directory setting", function()
		expect(wiki_modal.categories).toBeDefined()
		expect(#wiki_modal.categories).toBeGreaterThan(0)
		expect(wiki_modal.settings.docs_dir).toBeDefined()
	end)

	it("registers KrsWiki and NvimWiki user commands", function()
		wiki_modal.setup()
		local cmds = vim.api.nvim_get_commands({})
		expect(cmds["KrsWiki"]).toBeDefined()
		expect(cmds["NvimWiki"]).toBeDefined()
	end)

	it("toggles open and closed cleanly", function()
		expect(function()
			wiki_modal.open()
			wiki_modal.close()
		end).not_.toThrow()
	end)
end)
