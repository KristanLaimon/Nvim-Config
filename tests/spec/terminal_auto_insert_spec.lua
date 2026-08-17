-- ============================================================================
-- tests/spec/terminal_auto_insert_spec.lua -- Spec for Terminal auto-insert & click behavior
-- ============================================================================
local t = require("krsnvim.test")
local describe, it, expect, afterEach = t.describe, t.it, t.expect, t.afterEach

local terminal = require("plugins.krs.terminal")

describe("terminal auto insert & click behavior", function()
	local created_bufs = {}

	afterEach(function()
		for _, buf in ipairs(created_bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
		created_bufs = {}
	end)

	it("registers setup and LeftMouse mapping for terminal buffers", function()
		terminal.setup()

		local buf = vim.api.nvim_create_buf(false, true)
		table.insert(created_bufs, buf)
		vim.b[buf].krs_is_multi_term = true

		vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })

		local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
		local has_left_mouse = false
		for _, map in ipairs(keymaps) do
			if map.lhs == "<LeftMouse>" then
				has_left_mouse = true
				break
			end
		end

		expect(has_left_mouse).toBeTruthy()
	end)
end)
