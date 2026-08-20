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

local function center(text, width)
	local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
	return string.rep(" ", pad) .. text
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
		table.insert(lines, center(btn.label, width))
		table.insert(hls, nil)
		button_rows[#lines] = btn
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

--- Redraws dashboard content into the existing buffer, if still open.
function M.redraw()
	if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
		return
	end
	local lines, hls, button_rows = build()

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	for row, hl in pairs(hls) do
		if hl then
			pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, hl, row - 1, 0, -1)
		end
	end

	for _, key in ipairs({ "f", "p", "s", "w", "e", "m", "q", "l" }) do
		pcall(vim.keymap.del, "n", key, { buffer = state.buf })
	end
	for _, btn in pairs(button_rows) do
		vim.keymap.set("n", btn.key, function()
			vim.cmd(btn.cmd)
		end, { buffer = state.buf, silent = true, nowait = true })
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

	for opt, val in pairs({
		number = false,
		relativenumber = false,
		cursorline = false,
		signcolumn = "no",
		wrap = false,
		spell = false,
		list = false,
	}) do
		pcall(vim.api.nvim_set_option_value, opt, val, { win = state.win })
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
