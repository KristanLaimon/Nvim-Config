-- ============================================================================
-- tests/spec/git_center_spec.lua -- Lifecycle, toggle, buffer flags and keys.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect, beforeEach, afterEach = t.describe, t.it, t.expect, t.beforeEach, t.afterEach
local git_center = require("plugins.krs.git_center")

describe("plugins.krs.git_center", function()
	beforeEach(function()
		if git_center.is_open() then
			git_center.close_git_center()
		end
	end)

	afterEach(function()
		if git_center.is_open() then
			git_center.close_git_center()
		end
	end)

	it("exports public API methods and settings", function()
		expect(type(git_center.open_git_center)).toBe("function")
		expect(type(git_center.close_git_center)).toBe("function")
		expect(type(git_center.toggle_git_center)).toBe("function")
		expect(type(git_center.is_open)).toBe("function")
		expect(type(git_center.stage_all_with_modal)).toBe("function")
		expect(type(git_center.settings)).toBe("table")
		expect(type(git_center.settings.keys)).toBe("table")
	end)

	it("toggles open and closed cleanly", function()
		expect(git_center.is_open()).toBeFalsy()

		git_center.toggle_git_center()
		expect(git_center.is_open()).toBeTruthy()
		expect(git_center.main_win).toBeDefined()
		expect(git_center.preview_win).toBeDefined()
		expect(vim.api.nvim_win_is_valid(git_center.main_win)).toBeTruthy()
		expect(vim.api.nvim_win_is_valid(git_center.preview_win)).toBeTruthy()

		git_center.toggle_git_center()
		expect(git_center.is_open()).toBeFalsy()
		expect(git_center.main_win).toBeNil()
		expect(git_center.preview_win).toBeNil()
	end)

	it("creates unlisted scratch buffers with nofile and wipe flags", function()
		git_center.open_git_center()

		local main_buf = git_center.main_buf
		local preview_buf = git_center.preview_buf

		expect(vim.bo[main_buf].buftype).toBe("nofile")
		expect(vim.bo[main_buf].bufhidden).toBe("wipe")
		expect(vim.bo[main_buf].modifiable).toBeFalsy()

		expect(vim.bo[preview_buf].buftype).toBe("nofile")
		expect(vim.bo[preview_buf].bufhidden).toBe("wipe")
		expect(vim.bo[preview_buf].modifiable).toBeFalsy()

		git_center.close_git_center()
	end)

	it("binds close keys across normal, visual, insert, and terminal modes in both buffers", function()
		git_center.open_git_center()

		local main_buf = git_center.main_buf
		local preview_buf = git_center.preview_buf

		local close_keys = { "<Esc>", "q", "<C-S-g>", "<C-S-G>", "<C-g>", "<C-G>" }
		local modes = { "n", "v", "i", "t" }

		for _, key in ipairs(close_keys) do
			for _, mode in ipairs(modes) do
				local main_map = vim.api.nvim_buf_call(main_buf, function()
					return vim.fn.maparg(key, mode, false, true)
				end)
				expect({ key = key, mode = mode, buf = "main", bound = (main_map.buffer == 1) }).toEqual({
					key = key,
					mode = mode,
					buf = "main",
					bound = true,
				})

				local preview_map = vim.api.nvim_buf_call(preview_buf, function()
					return vim.fn.maparg(key, mode, false, true)
				end)
				expect({ key = key, mode = mode, buf = "preview", bound = (preview_map.buffer == 1) }).toEqual({
					key = key,
					mode = mode,
					buf = "preview",
					bound = true,
				})
			end
		end

		git_center.close_git_center()
	end)

	it("closes all windows when close_git_center is called", function()
		git_center.open_git_center()
		local main_win = git_center.main_win
		local prev_win = git_center.preview_win

		expect(vim.api.nvim_win_is_valid(main_win)).toBeTruthy()
		expect(vim.api.nvim_win_is_valid(prev_win)).toBeTruthy()

		git_center.close_git_center()

		expect(git_center.is_open()).toBeFalsy()
		expect(git_center.main_win).toBeNil()
		expect(git_center.preview_win).toBeNil()
		expect(vim.api.nvim_win_is_valid(main_win)).toBeFalsy()
		expect(vim.api.nvim_win_is_valid(prev_win)).toBeFalsy()
	end)

	it("binds tab switching keys in both main and preview buffers", function()
		git_center.open_git_center()

		local main_buf = git_center.main_buf
		local preview_buf = git_center.preview_buf

		local tab_keys = { "<A-h>", "<A-l>" }
		for _, key in ipairs(tab_keys) do
			local main_map = vim.api.nvim_buf_call(main_buf, function()
				return vim.fn.maparg(key, "n", false, true)
			end)
			expect({ key = key, buf = "main", bound = (main_map.buffer == 1) }).toEqual({
				key = key,
				buf = "main",
				bound = true,
			})

			local preview_map = vim.api.nvim_buf_call(preview_buf, function()
				return vim.fn.maparg(key, "n", false, true)
			end)
			expect({ key = key, buf = "preview", bound = (preview_map.buffer == 1) }).toEqual({
				key = key,
				buf = "preview",
				bound = true,
			})
		end

		git_center.close_git_center()
	end)
end)

