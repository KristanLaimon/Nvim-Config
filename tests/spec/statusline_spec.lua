-- ============================================================================
-- tests/spec/statusline_spec.lua -- Statusline engine & theme picker.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local statusline = require("plugins.krs.statusline_picker")

describe("plugins.krs.statusline_picker", function()
	it("formats modes into NvChad icon pills", function()
		expect(statusline.format_mode("NORMAL")).toBe(" NORMAL")
		expect(statusline.format_mode("INSERT")).toBe("󰏫 INSERT")
		expect(statusline.format_mode("VISUAL")).toBe("󰈈 VISUAL")
		expect(statusline.format_mode("COMMAND")).toBe("󰘳 COMMAND")
	end)

	it("returns valid lualine options for all supported themes", function()
		local themes = { "nvchad_pills", "nvchad_blocks", "nagatoro_classic", "vscode", "minimal" }
		for _, name in ipairs(themes) do
			local cfg = statusline.get_lualine_config(name)
			expect(cfg).toBeDefined()
			expect(cfg.options).toBeDefined()
			expect(cfg.sections).toBeDefined()
			expect(cfg.sections.lualine_a).toBeDefined()
		end
	end)

	it("registers KrsStatuslineTheme user command", function()
		statusline.setup()
		local cmds = vim.api.nvim_get_commands({})
		expect(cmds["KrsStatuslineTheme"]).toBeDefined()
	end)
end)
