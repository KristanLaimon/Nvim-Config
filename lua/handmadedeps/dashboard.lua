-- ============================================================================
-- HANDMADEDEPS: dashboard -- pure-Lua replacement for goolord/alpha-nvim.
-- ============================================================================
-- Exposes just enough of alpha-nvim's API for the KRS dashboard theme:
-- `.setup(opts)`, `.redraw()`, `.draw()`, and `.themes.dashboard` with
-- `section.header/buttons/footer` and `.button(key, label, cmd)`.
-- ============================================================================

local M = {}

local ns = vim.api.nvim_create_namespace("handmadedeps_dashboard")
local state = { buf = nil, win = nil }

M.themes = {
	dashboard = {
		section = {
			header = { val = {}, opts = {} },
			buttons = { val = {} },
			footer = { val = "" },
		},
		opts = {},
	},
}

--- Builds a button descriptor. Mirrors `alpha.themes.dashboard.button`.
--- @param key string Single-char normal-mode trigger.
--- @param label string Display text.
--- @param cmd string Ex command run on press, e.g. ":Telescope<CR>".
function M.themes.dashboard.button(key, label, cmd)
	return { key = key, label = label, cmd = cmd }
end

local function center_pad(text, width)
	return math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
end

local function center(text, width)
	return string.rep(" ", center_pad(text, width)) .. text
end

--- Renders the current theme state into `lines` and per-line highlight groups.
local function build()
	local dash = M.themes.dashboard
	local width = vim.o.columns
	local lines, hls = {}, {}

	local header_hl = dash.section.header.opts and dash.section.header.opts.hl
	for _, h in ipairs(dash.section.header.val) do
		table.insert(lines, center(h, width))
		table.insert(hls, header_hl)
	end

	table.insert(lines, "")
	table.insert(hls, nil)

	local button_rows = {}
	for _, btn in ipairs(dash.section.buttons.val) do
		local text = string.format("[%s]  %s", btn.key, btn.label)
		table.insert(lines, center(text, width))
		table.insert(hls, nil)
		button_rows[#lines] = { btn = btn, col = center_pad(text, width) }
		table.insert(lines, "")
		table.insert(hls, nil)
	end

	table.insert(lines, center(dash.section.footer.val, width))
	table.insert(hls, "Comment")

	local height = vim.o.lines - vim.o.cmdheight - 2
	local pad_top = math.max(0, math.floor((height - #lines) / 2))
	local padded, padded_hls = {}, {}
	for _ = 1, pad_top do
		table.insert(padded, "")
		table.insert(padded_hls, nil)
	end
	local shifted_rows = {}
	for i, l in ipairs(lines) do
		table.insert(padded, l)
		table.insert(padded_hls, hls[i])
		if button_rows[i] then
			shifted_rows[#padded] = button_rows[i]
		end
	end

	return padded, padded_hls, shifted_rows
end

--- Moves the cursor onto the given button row, at the button's text column.
local function goto_row(row)
	local entry = state.button_rows and state.button_rows[row]
	if not entry or not (state.win and vim.api.nvim_win_is_valid(state.win)) then
		return
	end
	pcall(vim.api.nvim_win_set_cursor, state.win, { row, entry.col })
end

--- Returns the sorted list of button row numbers.
local function button_row_numbers()
	local rows = {}
	for row in pairs(state.button_rows or {}) do
		table.insert(rows, row)
	end
	table.sort(rows)
	return rows
end

--- Moves the cursor to the next/previous button row, wrapping around.
local function step_row(direction)
	local rows = button_row_numbers()
	if #rows == 0 then
		return
	end
	local cur = vim.api.nvim_win_get_cursor(0)[1]
	local idx = 1
	for i, r in ipairs(rows) do
		if r == cur then
			idx = i
			break
		end
		if r > cur then
			idx = direction > 0 and i or math.max(1, i - 1)
			break
		end
		idx = i
	end
	local target = ((idx - 1 + direction) % #rows) + 1
	goto_row(rows[target])
end

--- Activates the button on the current row, if any.
local function activate_current()
	local cur = vim.api.nvim_win_get_cursor(0)[1]
	local entry = state.button_rows and state.button_rows[cur]
	if entry then
		vim.cmd(entry.btn.cmd)
	end
end

--- Redraws dashboard content into the existing buffer, if still open.
function M.redraw()
	if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
		return
	end
	local lines, hls, button_rows = build()
	state.button_rows = button_rows

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	for row, hl in pairs(hls) do
		if hl then
			pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, hl, row - 1, 0, -1)
		end
	end

	for _, key in ipairs(state.bound_keys or {}) do
		pcall(vim.keymap.del, "n", key, { buffer = state.buf })
	end
	state.bound_keys = {}
	for _, entry in pairs(button_rows) do
		local btn = entry.btn
		vim.keymap.set("n", btn.key, function()
			vim.cmd(btn.cmd)
		end, { buffer = state.buf, silent = true, nowait = true })
		table.insert(state.bound_keys, btn.key)
	end

	local rows = button_row_numbers()
	if rows[1] then
		goto_row(rows[1])
	end
end

--- Opens (or refreshes) the dashboard in the current window.
--- @param force boolean|nil Open even if the current buffer holds real content.
function M.start(force)
	local cur = vim.api.nvim_get_current_buf()
	if not force then
		if vim.bo[cur].filetype == "alpha" then
			return
		end
		if vim.api.nvim_buf_get_name(cur) ~= "" or vim.bo[cur].modified or vim.bo[cur].buftype ~= "" then
			return
		end
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "alpha"

	vim.api.nvim_set_current_buf(buf)
	state.buf = buf
	state.win = vim.api.nvim_get_current_win()
	-- A fresh buffer has no keymaps yet; forget the previous buffer's bound
	-- button keys so redraw() doesn't try to delete them here.
	state.bound_keys = nil

	for opt, val in pairs({
		number = false,
		relativenumber = false,
		cursorline = true,
		signcolumn = "no",
		wrap = false,
		spell = false,
		list = false,
	}) do
		pcall(vim.api.nvim_set_option_value, opt, val, { win = state.win })
	end

	-- Confines the cursor to button rows/columns: any stray movement snaps back.
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf,
		callback = function()
			if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
				return
			end
			local pos = vim.api.nvim_win_get_cursor(state.win)
			local entry = state.button_rows and state.button_rows[pos[1]]
			if not entry then
				local rows = button_row_numbers()
				local nearest = rows[1]
				for _, r in ipairs(rows) do
					if math.abs(r - pos[1]) < math.abs(nearest - pos[1]) then
						nearest = r
					end
				end
				if nearest then
					goto_row(nearest)
				end
				return
			end
			if pos[2] ~= entry.col then
				goto_row(pos[1])
			end
		end,
	})

	-- vim.keymap.set consumes (mutates) its opts table, so each call needs its own.
	local function buf_opts()
		return { buffer = buf, silent = true, nowait = true }
	end

	for _, key in ipairs({ "j", "<Down>" }) do
		vim.keymap.set("n", key, function()
			step_row(1)
		end, buf_opts())
	end
	for _, key in ipairs({ "k", "<Up>" }) do
		vim.keymap.set("n", key, function()
			step_row(-1)
		end, buf_opts())
	end
	vim.keymap.set("n", "<Tab>", function()
		step_row(1)
	end, buf_opts())
	vim.keymap.set("n", "<S-Tab>", function()
		step_row(-1)
	end, buf_opts())
	vim.keymap.set("n", "<CR>", activate_current, buf_opts())
	for _, key in ipairs({ "h", "l", "<Left>", "<Right>", "w", "b", "e", "0", "$", "^", "gg", "G" }) do
		pcall(vim.keymap.set, "n", key, "<Nop>", buf_opts())
	end

	M.redraw()
end

--- Draws the dashboard if appropriate for the current buffer. Safe to call blindly.
function M.draw()
	M.start(false)
end

--- Registers the `:Alpha` command and the startup autocmd. `opts` is accepted
--- for API compatibility but the theme state already lives on `M.themes`.
function M.setup(_)
	vim.api.nvim_create_user_command("Alpha", function()
		M.start(true)
	end, { desc = "Open the KRS dashboard" })

	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			if vim.fn.argc() ~= 0 then
				return
			end
			if vim.g.started_by_firenvim then
				return
			end
			local listed = vim.tbl_filter(function(b)
				return vim.fn.buflisted(b) == 1
			end, vim.api.nvim_list_bufs())
			if #listed > 1 then
				return
			end
			M.start(false)
		end,
	})
end

return M
