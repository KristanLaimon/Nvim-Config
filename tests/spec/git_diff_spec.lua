-- ============================================================================
-- tests/spec/git_diff_spec.lua -- Diff formatting for the preview pane.
-- ============================================================================
-- Two invariants matter here: the noise never reaches the buffer, and every
-- emitted line carries a kind, because the highlighter indexes them in parallel.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local diff = require("krs.git.diff")

local SAMPLE = {
	"diff --git a/init.lua b/init.lua",
	"index 1234567..89abcde 100644",
	"--- a/init.lua",
	"+++ b/init.lua",
	"@@ -1,3 +1,4 @@ local M = {}",
	" context line",
	"-removed line",
	"+added line",
}

describe("git diff format", function()
	it("drops the machine header lines", function()
		local lines = diff.format(SAMPLE, false)

		for _, line in ipairs(lines) do
			expect(line:match("^diff %-%-git")).toBeNil()
			expect(line:match("^index %x+")).toBeNil()
			expect(line:match("^%+%+%+ b/")).toBeNil()
		end
	end)

	it("keeps the content lines and tags each one", function()
		local lines, kinds = diff.format(SAMPLE, false)

		expect(#lines).toBe(#kinds)
		expect(lines).toContain(" context line")
		expect(lines).toContain("-removed line")
		expect(lines).toContain("+added line")
		expect(kinds).toContain("add")
		expect(kinds).toContain("delete")
		expect(kinds).toContain("context")
	end)

	it("replaces the @@ header with a labelled separator", function()
		local lines, kinds = diff.format(SAMPLE, false)

		expect(kinds[1]).toBe("header")
		expect(lines[1]).toContain("Hunk 1")
		expect(lines[1]).toContain("local M = {}")
	end)

	it("numbers multiple hunks", function()
		local lines = diff.format({
			"@@ -1,1 +1,1 @@",
			"+one",
			"@@ -9,1 +9,1 @@",
			"+two",
		}, false)

		expect(lines[1]).toContain("Hunk 1")
		expect(lines[3]).toContain("Hunk 2")
	end)

	it("renders an untracked file as all additions", function()
		local lines, kinds = diff.format({ "first", "second" }, true)

		expect(lines[2]).toBe("+ first")
		expect(lines[3]).toBe("+ second")
		expect(kinds[2]).toBe("add")
	end)

	it("splits embedded newlines, which nvim_buf_set_lines rejects", function()
		local lines = diff.format({ "one\ntwo" }, true)

		for _, line in ipairs(lines) do
			expect(line:find("\n")).toBeNil()
		end
	end)

	it("says so when a diff carries no visible change", function()
		local lines, kinds = diff.format({ "diff --git a/x b/x", "old mode 100644" }, false)

		expect(lines).toEqual({ diff.empty_message })
		expect(kinds).toEqual({ "context" })
	end)
end)

describe("git diff highlighting", function()
	it("marks each line with the group for its kind", function()
		diff.setup_highlights()

		local buf = vim.api.nvim_create_buf(false, true)
		local lines, kinds = diff.format(SAMPLE, false)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		diff.apply_highlights(buf, kinds)

		local marks = vim.api.nvim_buf_get_extmarks(buf, diff.namespace, 0, -1, {})
		expect(#marks).toBe(#kinds)

		vim.api.nvim_buf_delete(buf, { force = true })
	end)
end)
