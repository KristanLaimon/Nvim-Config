-- ============================================================================
-- HANDMADEDEPS: notify -- pure-Lua replacement for rcarriga/nvim-notify.
-- ============================================================================
-- Drop-in for the subset of the nvim-notify API this config actually calls:
-- `setup(opts)`, `history()`, `dismiss(opts)`, and `notify(msg, level, opts)`
-- callable as `require("notify")(...)`. Builds on the ease-in-out slide/fade
-- engine already used as the emergency fallback in krs.core.notify.
-- ============================================================================

local uv = vim.uv or vim.loop

-- Neovide runs its own window opacity/blur compositor (neovide_opacity,
-- neovide_window_blurred); layering animated winblend on top of that has
-- been observed to break Neovide's blur into flat transparency instead.
-- Terminal Neovim has no such conflict, so it keeps the winblend fade.
-- Checked live (not cached at require time): vim.g.neovide is set by the
-- GUI client announcing itself and isn't guaranteed to exist yet when this
-- module first loads, so caching it once could freeze in a false "false".
local function skip_winblend()
	return vim.g.neovide ~= nil
end

local M = {}

M.active_wins = {}
M.history_list = {}
M._opts = {}

local LEVEL_NAMES = { [0] = "TRACE", [1] = "DEBUG", [2] = "INFO", [3] = "WARN", [4] = "ERROR" }
local ICONS = {
	ERROR = "",
	WARN = "",
	INFO = "",
	DEBUG = "",
	TRACE = "✎",
}
local HIGHLIGHTS = {
	ERROR = "DiagnosticError",
	WARN = "DiagnosticWarn",
	INFO = "DiagnosticInfo",
	DEBUG = "DiagnosticHint",
	TRACE = "DiagnosticHint",
}

-- ============================================================================
-- Small pure helpers
-- ============================================================================

local function ease_in_out(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2
	end
end

local function resolve(val, ...)
	if type(val) == "function" then
		return val(...)
	end
	return val
end

-- ============================================================================
-- Animation engine
-- ============================================================================
-- Every visual transition in this module (toast slide-up on reflow, the
-- entry slide-in, the exit slide-out) is the same shape: N eased ticks on a
-- repeating timer, then a teardown. `animate` owns that shape once so each
-- call site only supplies what actually differs -- the per-tick math.

--- Stops and closes a libuv timer exactly once. A repeating timer's callback
--- is deferred via vim.schedule_wrap, so several ticks can already be queued
--- by the time the first one calls stop()+close() -- without this guard the
--- next queued tick closes an already-closing handle and errors on repeat.
local function safe_close_timer(timer)
	if not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

--- Runs an eased animation on a repeating timer.
--- @param steps integer Number of ticks.
--- @param interval_ms integer Timer interval, in milliseconds.
--- @param on_tick fun(factor: number) Called each tick with the eased 0..1 progress.
--- @param on_done fun()|nil Called once, after the final tick closes the timer.
local function animate(steps, interval_ms, on_tick, on_done)
	local step = 0
	local timer = uv.new_timer()
	timer:start(0, interval_ms, vim.schedule_wrap(function()
		if timer:is_closing() then
			return
		end
		step = step + 1
		on_tick(ease_in_out(math.min(1.0, step / steps)))
		if step >= steps then
			safe_close_timer(timer)
			if on_done then
				on_done()
			end
		end
	end))
end

--- Repositions and re-blends one floating window in a single call, silently
--- no-op'ing once the window is gone (it may close mid-animation).
--- @param win integer
--- @param row integer
--- @param col integer
--- @param blend integer|nil Omitted (nil) under Neovide -- see skip_winblend().
local function set_win_pos(win, row, col, blend)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	pcall(vim.api.nvim_win_set_config, win, {
		relative = "editor",
		row = math.max(0, row),
		col = math.max(0, col),
		focusable = false,
		noautocmd = true,
	})
	if blend and not skip_winblend() then
		pcall(vim.api.nvim_win_set_option, win, "winblend", blend)
	end
end

--- Closes a toast's window+buffer, drops it from active_wins, and reflows
--- the remaining stack. Shared by the "static" (no animation) timeout path
--- and the exit-animation's final tick.
--- @param win integer
--- @param buf integer
local function remove_win(win, buf)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	for idx, item in ipairs(M.active_wins) do
		if item.win == win then
			table.remove(M.active_wins, idx)
			break
		end
	end
	M.reposition_wins()
end

-- ============================================================================
-- Stacking
-- ============================================================================

--- Recomputes stacked positions for all active toasts (slide-up on close).
function M.reposition_wins()
	local top_down = M._opts.top_down ~= false
	local current_row = top_down and 1 or (vim.o.lines - 2)

	for _, item in ipairs(M.active_wins) do
		if item.win and vim.api.nvim_win_is_valid(item.win) then
			local target_row = top_down and current_row or (current_row - item.height)
			current_row = top_down and (current_row + item.height + 1) or (current_row - item.height - 1)
			item.target_row = target_row

			local start_row = item.current_row or target_row
			if start_row ~= target_row and M._opts.stages ~= "static" then
				animate(5, 25, function(factor)
					local animated_row = math.floor(start_row + (target_row - start_row) * factor + 0.5)
					item.current_row = animated_row
					set_win_pos(item.win, animated_row, item.current_col or 0)
				end)
			else
				item.current_row = target_row
			end
		end
	end
end

--- Dismisses all active toasts.
--- @param opts table|nil { silent = boolean }
function M.dismiss(opts)
	for _, item in ipairs(M.active_wins) do
		if item.win and vim.api.nvim_win_is_valid(item.win) then
			pcall(vim.api.nvim_win_close, item.win, true)
		end
		if item.buf and vim.api.nvim_buf_is_valid(item.buf) then
			pcall(vim.api.nvim_buf_delete, item.buf, { force = true })
		end
	end
	M.active_wins = {}
	if not (opts and opts.silent) then
		vim.cmd("redraw")
	end
end

--- Returns notification history (most recent last), mirroring nvim-notify's API.
--- @return table[] history
function M.history()
	return M.history_list
end

-- ============================================================================
-- Building one notification
-- ============================================================================

--- Formats a notification's display lines and the highlight group for its
--- title line. Pure: no window/buffer state.
--- @param msg_str string
--- @param level_name string
--- @param title string
--- @param compact boolean
--- @return string[] lines, string hl
local function build_lines(msg_str, level_name, title, compact)
	local icon = ICONS[level_name] or ICONS.INFO
	local hl = HIGHLIGHTS[level_name] or HIGHLIGHTS.INFO

	local lines = {}
	if title ~= "" then
		table.insert(lines, string.format("%s %s", icon, title))
		if not compact then
			table.insert(lines, string.rep("─", math.max(20, #title + 4)))
		end
	end
	for line in msg_str:gmatch("[^\r\n]+") do
		table.insert(lines, (title == "" and (icon .. " ") or " ") .. line)
	end
	return lines, hl
end

--- Computes the floating window's pixel geometry from its rendered lines.
--- Pure: no window/buffer state.
--- @param lines string[]
--- @param max_w integer
--- @param max_h integer
--- @return integer width, integer height
local function measure_geometry(lines, max_w, max_h)
	local max_line_len = 0
	local total_visual_lines = 0
	for _, l in ipairs(lines) do
		local display_w = vim.fn.strdisplaywidth(l)
		max_line_len = math.max(max_line_len, display_w + 2)
		total_visual_lines = total_visual_lines + math.max(1, math.ceil((display_w + 1) / math.max(1, max_w - 2)))
	end
	local width = math.max(10, math.min(max_line_len, max_w))
	local height = math.max(1, math.min(total_visual_lines, max_h))
	return width, height
end

--- Computes the target/start row and column for a new toast, accounting for
--- toasts already stacked above/below it.
--- @param height integer
--- @param width integer
--- @param static boolean
--- @return integer target_row, integer target_col, integer start_col
local function place_window(height, width, static)
	local top_down = M._opts.top_down ~= false
	local target_row = top_down and 1 or (vim.o.lines - 2)
	for _, item in ipairs(M.active_wins) do
		target_row = top_down and (target_row + item.height + 1) or (target_row - item.height - 1)
	end
	if not top_down then
		target_row = target_row - height
	end

	local target_col = math.max(0, vim.o.columns - width - 2)
	local start_col = static and target_col or vim.o.columns
	return target_row, target_col, start_col
end

--- Runs the entry slide-in animation for a freshly opened toast window.
local function animate_entry(win, win_item, start_col, target_col)
	animate(6, 20, function(factor)
		local animated_col = math.floor(start_col - (start_col - target_col) * factor + 0.5)
		win_item.current_col = animated_col
		set_win_pos(win, win_item.current_row, animated_col, math.floor(80 - (80 - 15) * factor + 0.5))
	end)
end

--- Runs the exit slide-out animation, then tears the toast down.
local function animate_exit(win, buf, win_item, target_col)
	local exit_start_col = win_item.current_col or target_col
	local exit_end_col = vim.o.columns
	animate(5, 20, function(factor)
		local animated_col = math.floor(exit_start_col + (exit_end_col - exit_start_col) * factor + 0.5)
		set_win_pos(win, win_item.current_row, animated_col, math.floor(15 + (90 - 15) * factor + 0.5))
	end, function()
		remove_win(win, buf)
	end)
end

--- Schedules a toast's auto-dismiss (static: instant close; animated: slide
--- out first) after `timeout` milliseconds. No-op if `timeout` is `false`.
local function schedule_dismiss(win, buf, win_item, target_col, static, timeout)
	if timeout == false then
		return
	end
	vim.defer_fn(function()
		if not vim.api.nvim_win_is_valid(win) then
			return
		end
		if static then
			remove_win(win, buf)
			return
		end
		animate_exit(win, buf, win_item, target_col)
	end, timeout)
end

--- Core notify implementation. Called as `require("notify")(msg, level, opts)`.
--- @param msg string|table
--- @param level number|string|nil
--- @param opts table|nil
function M.notify(msg, level, opts)
	if not msg or msg == "" then
		return
	end
	opts = opts or {}

	local level_name
	if type(level) == "string" then
		level_name = level:upper()
	else
		level_name = LEVEL_NAMES[level or vim.log.levels.INFO] or "INFO"
	end
	local msg_str = type(msg) == "table" and table.concat(msg, "\n") or tostring(msg)

	table.insert(M.history_list, { message = msg, level = level_name, title = opts.title, time = uv.now() })
	if #M.history_list > 100 then
		table.remove(M.history_list, 1)
	end

	local title = opts.title or ""
	local lines, hl = build_lines(msg_str, level_name, title, M._opts.render == "compact")

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "notify"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local width, height = measure_geometry(lines, resolve(M._opts.max_width) or 60, resolve(M._opts.max_height) or 12)
	local static = M._opts.stages == "static"
	local target_row, target_col, start_col = place_window(height, width, static)

	local ok_win, win = pcall(vim.api.nvim_open_win, buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, target_row),
		col = start_col,
		style = "minimal",
		border = "rounded",
		focusable = false,
		noautocmd = true,
		zindex = 45,
	})
	if not ok_win or not win or not vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_echo({ { string.format("[%s] %s", title, msg_str), hl } }, true, {})
		return
	end

	pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
	pcall(vim.api.nvim_set_option_value, "linebreak", true, { win = win })
	if not skip_winblend() then
		pcall(vim.api.nvim_win_set_option, win, "winblend", static and 15 or 80)
	end
	if title ~= "" then
		pcall(vim.api.nvim_buf_add_highlight, buf, -1, hl, 0, 0, -1)
	end

	local win_item = { win = win, buf = buf, width = width, height = height, current_row = target_row, current_col = start_col }
	table.insert(M.active_wins, win_item)

	if M._opts.on_open then
		pcall(M._opts.on_open, win)
	end

	if not static then
		animate_entry(win, win_item, start_col, target_col)
	end

	schedule_dismiss(win, buf, win_item, target_col, static, opts.timeout or M._opts.timeout or 3000)
end

-- ============================================================================
-- Click-to-copy
-- ============================================================================

--- Copies a notification window's visible text to the system clipboard.
--- @param win integer
local function copy_win_text(win)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	vim.fn.setreg("+", text)
	vim.fn.setreg("*", text)
	vim.api.nvim_echo({ { "📋 Notification copied to clipboard!", "DiagnosticInfo" } }, false, {})
end

local LEFTMOUSE = vim.api.nvim_replace_termcodes("<LeftMouse>", true, true, true)

--- Registers a single global click watcher, once. A `focusable = false`
--- floating window never receives focus, so its own buffer-local
--- `<LeftMouse>` mapping never fires -- the click just lands wherever focus
--- already was. `getmousepos()` does a real hit-test by screen position
--- instead, so this catches the click regardless of focus and copies
--- instantly, no window switch required.
local function install_click_watcher()
	if M._click_watcher_installed then
		return
	end
	M._click_watcher_installed = true
	vim.on_key(function(key)
		if key ~= LEFTMOUSE then
			return
		end
		local pos = vim.fn.getmousepos()
		if not pos or not pos.winid or pos.winid == 0 then
			return
		end
		for _, item in ipairs(M.active_wins) do
			if item.win == pos.winid then
				copy_win_text(item.win)
				return
			end
		end
	end, vim.api.nvim_create_namespace("handmadedeps_notify_click"))
end

--- Configures the engine. Mirrors nvim-notify's `setup(opts)`.
--- @param opts table|nil
function M.setup(opts)
	M._opts = opts or {}
	install_click_watcher()
end

setmetatable(M, {
	__call = function(self, msg, level, opts)
		return self.notify(msg, level, opts)
	end,
})

return M
