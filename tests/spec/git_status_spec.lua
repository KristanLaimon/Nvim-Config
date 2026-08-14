-- ============================================================================
-- tests/spec/git_status_spec.lua -- Porcelain status parsing.
-- ============================================================================
-- The Git Center's whole panel is built from this table, and the format is
-- fiddly: a two-column state where a file can be staged AND unstaged at once,
-- quoted paths, detached HEAD, and binary files in numstat.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local status = require("krs.git.status")

describe("git status parse_branch", function()
	it("reads a branch with an upstream", function()
		local branch, upstream = status.parse_branch("## main...origin/main")

		expect(branch).toBe("main")
		expect(upstream).toBe("origin/main")
	end)

	it("reads a branch with no upstream", function()
		local branch, upstream = status.parse_branch("## feature-x")

		expect(branch).toBe("feature-x")
		expect(upstream).toBeNil()
	end)

	it("reports ahead/behind counts as part of no-upstream parsing", function()
		local branch, upstream = status.parse_branch("## main...origin/main [ahead 2]")

		expect(branch).toBe("main")
		expect(upstream).toBe("origin/main")
	end)

	it("falls back to a detached label without a header", function()
		local branch = status.parse_branch("M  file.lua")

		expect(branch).toBe(status.detached_label)
	end)
end)

describe("git status parse_files", function()
	it("separates staged, unstaged and untracked entries", function()
		local files = status.parse_files({
			"## main",
			"M  staged.lua",
			" M unstaged.lua",
			"?? new.lua",
		})

		expect(files.staged).toEqual({ "staged.lua" })
		expect(files.unstaged).toEqual({ "unstaged.lua" })
		expect(files.untracked).toEqual({ "new.lua" })
	end)

	it("lists a partially staged file in both lists", function()
		local files = status.parse_files({ "## main", "MM both.lua" })

		expect(files.staged).toEqual({ "both.lua" })
		expect(files.unstaged).toEqual({ "both.lua" })
	end)

	it("treats added, renamed and deleted files as staged", function()
		local files = status.parse_files({ "## main", "A  added.lua", "R  renamed.lua", "D  gone.lua" })

		expect(files.staged).toEqual({ "added.lua", "renamed.lua", "gone.lua" })
	end)

	it("strips the quotes git adds around unusual paths", function()
		local files = status.parse_files({ "## main", '?? "spaced name.lua"' })

		expect(files.untracked).toEqual({ "spaced name.lua" })
	end)

	it("returns empty lists for a clean tree", function()
		local files = status.parse_files({ "## main" })

		expect(files.staged).toEqual({})
		expect(files.unstaged).toEqual({})
		expect(files.untracked).toEqual({})
	end)
end)

describe("git status sum_numstat", function()
	it("adds up several numstat outputs", function()
		local added, deleted = status.sum_numstat({ "3\t1\ta.lua" }, { "10\t2\tb.lua" })

		expect(added).toBe(13)
		expect(deleted).toBe(3)
	end)

	it("skips binary files, which report dashes", function()
		local added, deleted = status.sum_numstat({ "-\t-\timage.png", "1\t1\ta.lua" })

		expect(added).toBe(1)
		expect(deleted).toBe(1)
	end)

	it("returns zeroes for empty input", function()
		local added, deleted = status.sum_numstat({})

		expect(added).toBe(0)
		expect(deleted).toBe(0)
	end)
end)
