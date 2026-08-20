-- ============================================================================
-- HANDMADEDEPS: bufferline -- pure-Lua replacement for akinsho/bufferline.nvim.
-- ============================================================================
-- Implements the subset actually used by this config: `setup(opts)`, ordered
-- buffer tabs rendered via `vim.o.tabline`, close/right/middle click routing,
-- a `groups` pin API (`add_element`/`remove_element`) consumed by
-- plugins/krs/pinned_tabs.lua, and `ui.refresh()`.
-- ============================================================================

local M = {}

M.opts = {}
M.pinned = {}
M.order = {}

local SLANT_RIGHT = "\u{e0b8}"

local function get_hl(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl and next(hl) then
		return hl
	end
	return nil
end

local function hex(n)
	return n and string.format("#%06x", n) or nil
end

--- (Re)derives the tab highlight groups from the active colorscheme: a bright
--- background for the selected tab, a dim one for inactive tabs, matching
--- backgrounds for their close icons, and a fill for unclaimed tabline space.
--- These are separate from `BufferLineBufferSelected/Visible` (which the
--- spec's `apply_tab_highlights()` forces to plain white text) so the tabs
--- keep visible contrast even with that override in place.
local function ensure_highlights()
	local normal = get_hl("Normal")
	local statusline = get_hl("StatusLine") or get_hl("TabLineFill") or {}
	local sel_bg = hex(normal and normal.bg) or "#282c34"
	local sel_fg = hex(normal and normal.fg) or "#ffffff"
	local dim_bg = hex(statusline.bg) or "#21252b"
	local dim_fg = hex((get_hl("Comment") or {}).fg) or "#5c6370"
	local accent = hex((get_hl("Function") or get_hl("Directory") or {}).fg) or "#61afef"

	vim.api.nvim_set_hl(0, "HmBufferLineSelected", { fg = accent, bg = sel_bg, bold = true })
	vim.api.nvim_set_hl(0, "HmBufferLineVisible", { fg = dim_fg, bg = dim_bg })
	vim.api.nvim_set_hl(0, "HmBufferLineCloseSelected", { fg = sel_fg, bg = sel_bg })
	vim.api.nvim_set_hl(0, "HmBufferLineCloseVisible", { fg = dim_fg, bg = dim_bg })
	vim.api.nvim_set_hl(0, "BufferLineFill", { bg = dim_bg })
	vim.api.nvim_set_hl(0, "HmBufferLineSlantSelected", { fg = sel_bg, bg = dim_bg })
	vim.api.nvim_set_hl(0, "HmBufferLineSlantVisible", { fg = dim_bg, bg = dim_bg })
end

M.groups = {
	builtin = { pinned = { id = "pinned" } },
}

--- Adds a buffer to a named group. Only "pinned" is meaningful here.
--- @param name string
--- @param element { id: integer }
function M.groups.add_element(name, element)
	if name == "pinned" and element and element.id then
		M.pinned[element.id] = true
	end
end

--- Removes a buffer from a named group.
--- @param name string
--- @param element { id: integer }
function M.groups.remove_element(name, element)
	if name == "pinned" and element and element.id then
		M.pinned[element.id] = nil
	end
end

M.ui = {
	refresh = function()
		pcall(vim.cmd, "redrawtabline")
	end,
}

local function is_listed_target(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.fn.buflisted(bufnr) ~= 1 then
		return false
	end
	if M.opts.custom_filter and not M.opts.custom_filter(bufnr) then
		return false
	end
	return true
end

--- Returns the visible, ordered buffer list: pinned first, then the rest, both
--- honouring `M.order` (manual left/right moves) and pruning stale entries.
local function ordered_buffers()
	local visible = {}
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if is_listed_target(b) then
			visible[b] = true
		end
	end

	local seen = {}
	local ordered = {}
	for _, b in ipairs(M.order) do
		if visible[b] and not seen[b] then
			table.insert(ordered, b)
			seen[b] = true
		end
	end
	local rest = {}
	for b in pairs(visible) do
		if not seen[b] then
			table.insert(rest, b)
		end
	end
	table.sort(rest)
	for _, b in ipairs(rest) do
		table.insert(ordered, b)
	end
	M.order = ordered

	local pinned, other = {}, {}
	for _, b in ipairs(ordered) do
		if M.pinned[b] then
			table.insert(pinned, b)
		else
			table.insert(other, b)
		end
	end

	local final = {}
	for _, b in ipairs(pinned) do
		table.insert(final, b)
	end
	for _, b in ipairs(other) do
		table.insert(final, b)
	end
	return final
end

--- Swaps the current buffer's tab with its left/right neighbour in `M.order`.
--- @param direction integer -1 (left) or 1 (right)
local function move_current(direction)
	local list = ordered_buffers()
	local cur = vim.api.nvim_get_current_buf()
	local idx
	for i, b in ipairs(list) do
		if b == cur then
			idx = i
			break
		end
	end
	if not idx then
		return
	end
	local target = idx + direction
	if target < 1 or target > #list then
		return
	end
	list[idx], list[target] = list[target], list[idx]
	M.order = list
	M.ui.refresh()
end

function M.cycle(direction)
	local list = ordered_buffers()
	if #list == 0 then
		return
	end
	local cur = vim.api.nvim_get_current_buf()
	local idx = 1
	for i, b in ipairs(list) do
		if b == cur then
			idx = i
			break
		end
	end
	local target = ((idx - 1 + direction) % #list) + 1
	pcall(vim.api.nvim_set_current_buf, list[target])
end

--- Click routing target for the label region of a tab (bufnr encoded as minwid).
function M.handle_tab_click(minwid, _, button)
	local bufnr = minwid
	if button == "l" then
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_set_current_buf, bufnr)
		end
	elseif button == "r" and M.opts.right_mouse_command then
		M.opts.right_mouse_command(bufnr)
	elseif button == "m" and M.opts.middle_mouse_command then
		M.opts.middle_mouse_command(bufnr)
	end
end

--- Click routing target for a tab's close icon.
function M.handle_close_click(minwid)
	if M.opts.close_command then
		M.opts.close_command(minwid)
	end
end

--- Finds the width/text of a configured offset (e.g. the neo-tree sidebar),
--- padded to the sidebar's exact width so tabs start flush with the code
--- window instead of overlapping the tree.
local function active_offset()
	for _, offset in ipairs(M.opts.offsets or {}) do
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == offset.filetype then
				local width = vim.api.nvim_win_get_width(win) + 1
				local text = offset.text or ""
				local pad = math.max(0, width - vim.fn.strdisplaywidth(text))
				local left_pad = offset.text_align == "center" and math.floor(pad / 2) or 0
				text = string.rep(" ", left_pad) .. text .. string.rep(" ", pad - left_pad)
				return width, text, offset.highlight
			end
		end
	end
	return 0, nil, nil
end

--- Resolves a buffer's display name, honouring the deleted-file marker and
--- the caller's `name_formatter`. Pure aside from the two read-only lookups.
--- @param bufnr integer
--- @return string short_name, string display_name
local function resolve_display_name(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"

	local display = short
	if _G.Is_File_Deleted and _G.Is_File_Deleted(bufnr) then
		display = "[D] " .. short
	end
	if M.opts.name_formatter then
		local ok, res = pcall(M.opts.name_formatter, { bufnr = bufnr, name = short })
		if ok and res then
			display = res
		end
	end
	return short, display
end

--- Builds one tab's full markup: the clickable label span, its close-icon
--- span (if enabled), and the trailing separator glyph before the next tab.
--- @param bufnr integer
--- @param is_selected boolean
--- @param is_last boolean
--- @param devicons table|nil The `nvim-web-devicons` module, if available.
--- @return string
local function render_tab(bufnr, is_selected, is_last, devicons)
	local short, display = resolve_display_name(bufnr)

	local icon, icon_hl = "", nil
	if devicons then
		local ic, hl = devicons.get_icon(short, vim.fn.fnamemodify(short, ":e"), { default = true })
		if ic then
			icon, icon_hl = ic, hl
		end
	end

	local hl_buf = is_selected and "HmBufferLineSelected" or "HmBufferLineVisible"
	local hl_close = is_selected and "HmBufferLineCloseSelected" or "HmBufferLineCloseVisible"
	local slant_hl = is_selected and "HmBufferLineSlantSelected" or "HmBufferLineSlantVisible"

	local pin_icon = M.pinned[bufnr] and "📌 " or ""
	local modified_icon = vim.bo[bufnr].modified and " " or " "
	local icon_span = icon ~= "" and string.format("%%#%s# %s%%#%s#", icon_hl or hl_buf, icon, hl_buf) or " "
	local label = string.format("%s%s %s%s", pin_icon, icon_span, display, modified_icon)

	local parts = {
		string.format(
			"%%#%s#%%%d@v:lua.require'handmadedeps.bufferline'.handle_tab_click@%s%%X",
			hl_buf,
			bufnr,
			label
		),
	}

	if M.opts.show_buffer_close_icons ~= false then
		table.insert(
			parts,
			string.format(
				"%%#%s#%%%d@v:lua.require'handmadedeps.bufferline'.handle_close_click@✗ %%X",
				hl_close,
				bufnr
			)
		)
	end

	if not is_last then
		table.insert(parts, string.format("%%#%s#%s", slant_hl, SLANT_RIGHT))
	end

	return table.concat(parts)
end

--- Builds the full `tabline` string for the current redraw.
function M.render()
	ensure_highlights()
	local list = ordered_buffers()
	local current = vim.api.nvim_get_current_buf()
	local has_devicons, devicons = pcall(require, "nvim-web-devicons")

	local parts = {}

	local offset_w, offset_text = active_offset()
	if offset_w > 0 and offset_text then
		parts[#parts + 1] = string.format("%%#BufferLineFill#%s", offset_text)
	end

	for i, bufnr in ipairs(list) do
		parts[#parts + 1] = render_tab(bufnr, bufnr == current, i == #list, has_devicons and devicons or nil)
	end

	-- No manual padding: a trailing highlight with no text already extends to
	-- fill unclaimed width, and padding here would push the real tab content
	-- past 'columns', triggering Vim's default (start-of-string) truncation.
	parts[#parts + 1] = "%#BufferLineFill#"
	return table.concat(parts)
end

--- Configures the engine and registers `BufferLine*` user commands.
--- @param spec table `{ options = {...}, highlights = {...} }`
function M.setup(spec)
	M.opts = (spec and spec.options) or {}

	-- Flipping 'showtabline'/'tabline' forces an immediate layout recalc.
	-- Doing that synchronously mid-startup (before the first frame settles)
	-- races Neovide's blur-behind compositor call and can leave it stuck
	-- flat-transparent instead of blurred. A same-tick vim.schedule() cut
	-- the failure rate but didn't eliminate it; waiting for the GUI to
	-- actually attach (UIEnter, same pattern config/options.lua uses for
	-- this exact race) plus a short real delay gives it real margin.
	local function apply()
		vim.defer_fn(function()
			vim.o.showtabline = M.opts.always_show_bufferline ~= false and 2 or 1
			vim.o.tabline = "%!v:lua.require'handmadedeps.bufferline'.render()"
		end, 30)
	end
	vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, { once = true, callback = apply })

	vim.api.nvim_create_user_command("BufferLineCycleNext", function()
		M.cycle(1)
	end, {})
	vim.api.nvim_create_user_command("BufferLineCyclePrev", function()
		M.cycle(-1)
	end, {})
	vim.api.nvim_create_user_command("BufferLineMoveNext", function()
		move_current(1)
	end, {})
	vim.api.nvim_create_user_command("BufferLineMovePrev", function()
		move_current(-1)
	end, {})

	vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter", "BufModifiedSet" }, {
		callback = function()
			pcall(vim.cmd, "redrawtabline")
		end,
	})
end

return M
