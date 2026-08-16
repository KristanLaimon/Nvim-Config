-- ============================================================================
-- tests/spec/installer_spec.lua -- KRS System Setup Installer spec.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local installer = require("krs.core.installer")

describe("krs.core.installer", function()
	it("renders unicode progress bar correctly", function()
		expect(installer.render_bar(0, 10)).toBe("░░░░░░░░░░")
		expect(installer.render_bar(50, 10)).toBe("█████░░░░░")
		expect(installer.render_bar(100, 10)).toBe("██████████")
	end)

	it("scans system status and reports component counts", function()
		local scan = installer.scan_status()
		expect(scan).toBeDefined()
		expect(type(scan.percentage)).toBe("number")
		expect(type(scan.installed_count)).toBe("number")
		expect(type(scan.total_count)).toBe("number")
		expect(scan.total_count > 0).toBe(true)
	end)

	it("saves, loads, and resets completion state", function()
		installer.save_state(true)
		local state = installer.load_state()
		expect(state.completed).toBe(true)

		installer.reset_state()
		local reset_state = installer.load_state()
		expect(reset_state.completed).toBe(false)
	end)

	it("opens Live Setup Floating Modal UI cleanly", function()
		installer.open_ui()
		local win = vim.api.nvim_get_current_win()
		expect(vim.api.nvim_win_is_valid(win)).toBe(true)
		local buf = vim.api.nvim_win_get_buf(win)
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		expect(#lines > 5).toBe(true)
		vim.api.nvim_win_close(win, true)
	end)

	it("registers user commands on init()", function()
		installer.init()
		local cmds = vim.api.nvim_get_commands({})
		expect(cmds["KrsSetup"]).toBeDefined()
		expect(cmds["KrsInstallAll"]).toBeDefined()
		expect(cmds["KrsSetupStatus"]).toBeDefined()
		expect(cmds["KrsSetupReset"]).toBeDefined()
	end)
end)
