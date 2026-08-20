-- ============================================================================
-- tests/spec/handmadedeps_bufferline_spec.lua -- handmadedeps.bufferline regression tests.
-- ============================================================================
-- Locks in the behavior fixed while replacing akinsho/bufferline.nvim: no
-- unbounded trailing pad that triggers Vim's default (start-of-string)
-- tabline truncation, offset text padded to the sidebar's exact width, and
-- pinned buffers sorted first.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect, beforeEach, afterEach = t.describe, t.it, t.expect, t.beforeEach, t.afterEach

describe("handmadedeps.bufferline", function()
	local bl
	local bufs = {}
	local wins = {}

	local function open_named_buf(name)
		local path = vim.fn.tempname() .. "_" .. name
		vim.fn.writefile({ "" }, path)
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		local buf = vim.api.nvim_get_current_buf()
		table.insert(bufs, buf)
		return buf
	end

	beforeEach(function()
		package.loaded["handmadedeps.bufferline"] = nil
		bl = require("handmadedeps.bufferline")
		bl.setup({
			options = {
				custom_filter = function(bufnr)
					return vim.bo[bufnr].buftype == ""
				end,
			},
		})
		bufs = {}
		wins = {}
	end)

	afterEach(function()
		-- Always runs, even if an assertion above threw -- an extra split
		-- window leaking into the next spec was exactly what turned one
		-- failing assertion here into a second, unrelated failure there.
		for _, win in ipairs(wins) do
			pcall(vim.api.nvim_win_close, win, true)
		end
		for _, buf in ipairs(bufs) do
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end)

	it("renders a tabline that keeps its real content instead of collapsing to '<'", function()
		-- Regression: padding the tabline out to vim.o.columns with literal
		-- spaces made the whole string wider than the window with no %<
		-- marker, so Vim's default truncation dropped every tab and left only
		-- the truncation indicator.
		open_named_buf("alpha.txt")
		open_named_buf("beta.txt")

		local raw = bl.render()
		local ok, res = pcall(vim.api.nvim_eval_statusline, raw, { use_tabline = true, maxwidth = vim.o.columns })

		expect(ok).toBeTruthy()
		expect(res.str).toContain("alpha.txt")
		expect(res.str).toContain("beta.txt")
		expect(res.str:match("^%s*<%s*$")).toBeNil()
	end)

	it("pads the sidebar offset to its exact window width", function()
		open_named_buf("main.txt")
		vim.cmd("vsplit")
		local win = vim.api.nvim_get_current_win()
		table.insert(wins, win)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(win, buf)
		vim.bo[buf].filetype = "neo-tree"
		vim.api.nvim_win_set_width(win, 25)

		package.loaded["handmadedeps.bufferline"] = nil
		bl = require("handmadedeps.bufferline")
		bl.setup({
			options = {
				offsets = { { filetype = "neo-tree", text = "Explorer", text_align = "left" } },
				custom_filter = function(b)
					return vim.bo[b].buftype == ""
				end,
			},
		})

		-- Read the actual width nvim settled on (splits can clamp a requested
		-- width) right before rendering, so the assertion matches what the
		-- renderer itself sees rather than the requested value.
		local sidebar_width = vim.api.nvim_win_get_width(win) + 1
		local raw = bl.render()
		local ok, res = pcall(vim.api.nvim_eval_statusline, raw, { use_tabline = true, maxwidth = vim.o.columns })
		expect(ok).toBeTruthy()

		-- Whatever tab comes right after the offset (nvim's own initial
		-- buffer 1 may still be listed and sort first -- irrelevant here),
		-- the offset prefix itself must be exactly the sidebar's width.
		local offset_text = res.str:sub(1, sidebar_width)
		expect(offset_text:match("^Explorer%s*$")).toBeDefined()
	end)

	it("sorts pinned buffers before the rest", function()
		local a = open_named_buf("a.txt")
		local b = open_named_buf("b.txt")
		bl.groups.add_element("pinned", { id = b })

		local raw = bl.render()
		local a_pos = raw:find(tostring(a) .. "@")
		local b_pos = raw:find(tostring(b) .. "@")

		expect(b_pos).toBeDefined()
		expect(a_pos).toBeDefined()
		expect(b_pos < a_pos).toBeTruthy()

		bl.groups.remove_element("pinned", { id = b })
	end)

	it("cycle() moves to the next buffer in order and wraps around", function()
		local a = open_named_buf("a.txt")
		local b = open_named_buf("b.txt")
		vim.api.nvim_set_current_buf(a)

		bl.cycle(1)
		expect(vim.api.nvim_get_current_buf()).toBe(b)

		bl.cycle(1)
		expect(vim.api.nvim_get_current_buf()).toBe(a)
	end)
end)
