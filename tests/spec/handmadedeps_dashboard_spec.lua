-- ============================================================================
-- tests/spec/handmadedeps_dashboard_spec.lua -- handmadedeps.dashboard regression tests.
-- ============================================================================
-- Locks in the behavior fixed while replacing goolord/alpha-nvim: centering
-- against the dashboard's own window (not the whole editor), no duplicate
-- keymaps between the nav-lock and a same-lettered button, stripped
-- feedkeys-style "<CR>" before vim.cmd, and a WinResized handler that
-- survives a wiped buffer.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect, beforeEach, afterEach = t.describe, t.it, t.expect, t.beforeEach, t.afterEach

describe("handmadedeps.dashboard", function()
	local alpha, dashboard
	local created_wins = {}

	beforeEach(function()
		package.loaded["handmadedeps.dashboard"] = nil
		alpha = require("handmadedeps.dashboard")
		dashboard = alpha.themes.dashboard
		dashboard.section.header.val = { "HEADER" }
		dashboard.section.buttons.val = {}
		dashboard.section.footer.val = "footer"
		alpha.setup({})
		created_wins = {}
	end)

	afterEach(function()
		for _, win in ipairs(created_wins) do
			pcall(vim.api.nvim_win_close, win, true)
		end
	end)

	it("button() builds a plain {key, label, cmd} descriptor", function()
		local btn = dashboard.button("f", "File Explorer", ":Telescope find_files<CR>")
		expect(btn).toEqual({ key = "f", label = "File Explorer", cmd = ":Telescope find_files<CR>" })
	end)

	it("centers content against its own window width, not the whole editor", function()
		vim.cmd("vsplit")
		local win = vim.api.nvim_get_current_win()
		table.insert(created_wins, win)
		vim.api.nvim_win_set_width(win, 40)

		alpha.start(true)
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

		local header_line
		for _, l in ipairs(lines) do
			if l:find("HEADER", 1, true) then
				header_line = l
				break
			end
		end
		expect(header_line).toBeDefined()

		local leading_spaces = #(header_line:match("^(%s*)"))
		local expected_pad = math.floor((40 - #"HEADER") / 2)
		expect(leading_spaces).toBe(expected_pad)
	end)

	it("never sets the same buffer-local key twice (nav-lock vs. a same-lettered button)", function()
		dashboard.section.buttons.val = {
			dashboard.button("f", "File Explorer", ":echo 1<CR>"),
			dashboard.button("w", "Wiki", ":echo 2<CR>"),
			dashboard.button("e", "Extensions", ":echo 3<CR>"),
			dashboard.button("l", "WSL Explorer", ":echo 4<CR>"),
		}
		alpha.start(true)
		local buf = vim.api.nvim_get_current_buf()

		local seen = {}
		for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
			seen[m.lhs] = (seen[m.lhs] or 0) + 1
		end
		local max_count = 0
		for _, count in pairs(seen) do
			max_count = math.max(max_count, count)
		end
		expect(max_count).toBe(1)
	end)

	it("button letters resolve to their command, not <Nop>", function()
		dashboard.section.buttons.val = {
			dashboard.button("w", "Wiki", ":echo 2<CR>"),
		}
		alpha.start(true)

		local mapping = vim.fn.maparg("w", "n", false, true)
		expect(mapping.rhs == "<Nop>").toBeFalsy()
	end)

	it("strips feedkeys-style ':' and '<CR>' before running a button command", function()
		local ran = {}
		vim.api.nvim_create_user_command("HmDashboardTestCmd", function()
			table.insert(ran, true)
		end, {})

		dashboard.section.buttons.val = {
			dashboard.button("x", "Test", ":HmDashboardTestCmd<CR>"),
		}
		alpha.start(true)

		vim.cmd("normal x")

		expect(#ran).toBe(1)
		pcall(vim.api.nvim_del_user_command, "HmDashboardTestCmd")
	end)

	it("confines the cursor to button rows and ignores plain motion keys", function()
		dashboard.section.buttons.val = {
			dashboard.button("f", "File Explorer", ":echo 1<CR>"),
			dashboard.button("q", "Quit", ":echo 2<CR>"),
		}
		alpha.start(true)
		local win = vim.api.nvim_get_current_win()

		local before = vim.api.nvim_win_get_cursor(win)
		vim.api.nvim_feedkeys("l", "x", false)
		local after = vim.api.nvim_win_get_cursor(win)

		expect(after).toEqual(before)
	end)

	it("WinResized does not error when the dashboard buffer has already been wiped", function()
		alpha.start(true)
		local buf = vim.api.nvim_get_current_buf()
		vim.cmd("enew") -- bufhidden=wipe deletes the dashboard buffer here
		expect(vim.api.nvim_buf_is_valid(buf)).toBeFalsy()

		local ok = pcall(vim.api.nvim_exec_autocmds, "WinResized", { pattern = "*" })
		expect(ok).toBeTruthy()
	end)

	it("does not use the 'cursorline' window option (Neovide blur collision)", function()
		alpha.start(true)
		expect(vim.wo.cursorline).toBe(false)
	end)
end)
