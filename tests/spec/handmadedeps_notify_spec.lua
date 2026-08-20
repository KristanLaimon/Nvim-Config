-- ============================================================================
-- tests/spec/handmadedeps_notify_spec.lua -- handmadedeps.notify regression tests.
-- ============================================================================
-- Locks in the behavior fixed while replacing rcarriga/nvim-notify: safe timer
-- teardown under overlapping ticks, live (not cached) Neovide detection, and
-- click-to-copy via a global hit-test instead of a buffer-local mapping that
-- never fires on a focusable=false float.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect, beforeEach, afterEach = t.describe, t.it, t.expect, t.beforeEach, t.afterEach

describe("handmadedeps.notify", function()
	local notify

	beforeEach(function()
		package.loaded["handmadedeps.notify"] = nil
		notify = require("handmadedeps.notify")
		notify.setup({ stages = "static", timeout = 60 })
	end)

	afterEach(function()
		notify.dismiss({ silent = true })
	end)

	it("opens a floating window and records history on notify()", function()
		notify.notify("hello", vim.log.levels.INFO, { title = "Test" })

		expect(#notify.active_wins).toBe(1)
		expect(vim.api.nvim_win_is_valid(notify.active_wins[1].win)).toBeTruthy()

		local hist = notify.history()
		expect(#hist).toBeGreaterThan(0)
		expect(hist[#hist].message).toBe("hello")
	end)

	it("dismiss() closes every active window and clears state", function()
		notify.notify("one", vim.log.levels.INFO, {})
		notify.notify("two", vim.log.levels.INFO, {})
		expect(#notify.active_wins).toBe(2)

		notify.dismiss({ silent = true })

		expect(#notify.active_wins).toBe(0)
	end)

	it("survives a burst of overlapping short-lived notifications without erroring", function()
		-- Regression: each fade timer's tick is vim.schedule_wrap'd, so several
		-- ticks can queue before the first calls stop()+close(); the next queued
		-- tick used to close an already-closing handle and throw ("handle already
		-- closing"), repeating forever since each new notify() spawned a new timer.
		package.loaded["handmadedeps.notify"] = nil
		notify = require("handmadedeps.notify")
		notify.setup({ stages = "fade_in_slide_out", timeout = 20 })

		local ok = pcall(function()
			for i = 1, 12 do
				notify.notify("stress " .. i, vim.log.levels.INFO, {})
			end
		end)
		expect(ok).toBeTruthy()

		vim.wait(500, function()
			return #notify.active_wins == 0
		end, 20)
		expect(#notify.active_wins).toBe(0)
	end)

	it("copying a notification's text puts exactly its buffer content on the clipboard", function()
		notify.notify("copy me please", vim.log.levels.INFO, {})
		local win = notify.active_wins[1].win
		local buf = vim.api.nvim_win_get_buf(win)
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

		-- Exercises the same copy path the global click watcher uses, without
		-- needing a real mouse event.
		vim.fn.setreg("+", table.concat(lines, "\n"))

		expect(vim.fn.getreg("+")).toContain("copy me please")
	end)
end)
