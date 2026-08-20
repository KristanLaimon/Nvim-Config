-- ============================================================================
-- tests/spec/handmadedeps_statusline_spec.lua -- handmadedeps.statusline regression tests.
-- ============================================================================
-- Locks in the behavior fixed while replacing nvim-lualine/lualine.nvim:
-- render() always produces real content (never a blank bar), and
-- 'laststatus'/'statusline' get applied (just deferred past Neovide's
-- startup blur race, not dropped).
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect, beforeEach = t.describe, t.it, t.expect, t.beforeEach

local function default_config()
	return {
		options = { theme = "auto", globalstatus = true },
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch", "diff", "diagnostics" },
			lualine_c = { "filename" },
			lualine_x = { "filetype" },
			lualine_y = { "encoding" },
			lualine_z = { "location", "progress" },
		},
	}
end

describe("handmadedeps.statusline", function()
	local sl

	beforeEach(function()
		package.loaded["handmadedeps.statusline"] = nil
		sl = require("handmadedeps.statusline")
	end)

	it("render() produces real content for the default section layout", function()
		sl.config = default_config()
		local raw = sl.render()
		local ok, res = pcall(vim.api.nvim_eval_statusline, raw, { maxwidth = 200 })

		expect(ok).toBeTruthy()
		expect(res.str:match("^%s*$")).toBeNil()
		expect(res.str:upper()).toContain("NORMAL")
	end)

	it("setup() applies laststatus/statusline once VimEnter/UIEnter fires", function()
		sl.setup(default_config())

		-- The assignment is deferred past the Neovide blur-race window, so it
		-- must not have landed synchronously yet.
		local before = vim.o.statusline

		vim.api.nvim_exec_autocmds("VimEnter", { pattern = "*" })
		vim.wait(200, function()
			return vim.o.statusline ~= before
		end, 10)

		expect(vim.o.statusline).toContain("handmadedeps.statusline")
		expect(vim.o.laststatus).toBe(3)
	end)

	it("does not error when Normal/StatusLine highlights are unset", function()
		local ok = pcall(function()
			vim.api.nvim_set_hl(0, "Normal", {})
			vim.api.nvim_set_hl(0, "StatusLine", {})
			sl.config = default_config()
			sl.render()
		end)
		expect(ok).toBeTruthy()
	end)
end)
