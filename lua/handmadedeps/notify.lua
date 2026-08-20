-- ============================================================================
-- HANDMADEDEPS: notify -- pure-Lua replacement for rcarriga/nvim-notify.
-- ============================================================================
-- Drop-in for the subset of the nvim-notify API this config actually calls:
-- `setup(opts)`, `history()`, `dismiss(opts)`, and `notify(msg, level, opts)`
-- callable as `require("notify")(...)`. Builds on the ease-in-out slide/fade
-- engine already used as the emergency fallback in krs.core.notify.
-- ============================================================================

local uv = vim.uv or vim.loop

local M = {}

M.active_wins = {}
M.history_list = {}
M._opts = {}

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

local function ease_in_out(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2
	end
end

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

local function resolve(val, ...)
	if type(val) == "function" then
		return val(...)
	end
	return val
end

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
				local steps = 5
				local step = 0
				local timer = uv.new_timer()
				timer:start(0, 25, vim.schedule_wrap(function()
					if timer:is_closing() then
						return
					end
					step = step + 1
					local t = math.min(1.0, step / steps)
					local factor = ease_in_out(t)
					local animated_row = math.floor(start_row + (target_row - start_row) * factor + 0.5)
					item.current_row = animated_row
					if item.win and vim.api.nvim_win_is_valid(item.win) then
						pcall(vim.api.nvim_win_set_config, item.win, {
							relative = "editor",
							row = math.max(0, animated_row),
							col = math.max(0, item.current_col or 0),
							focusable = false,
							noautocmd = true,
						})
					end
					if step >= steps then
						safe_close_timer(timer)
					end
				end))
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

	local icon = ICONS[level_name] or ICONS.INFO
	local hl = HIGHLIGHTS[level_name] or HIGHLIGHTS.INFO
	local title = opts.title or ""
	local compact = M._opts.render == "compact"

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

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "notify"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local max_w = resolve(M._opts.max_width) or 60
	local max_h = resolve(M._opts.max_height) or 12

	local max_line_len = 0
	local total_visual_lines = 0
	for _, l in ipairs(lines) do
		max_line_len = math.max(max_line_len, vim.fn.strdisplaywidth(l) + 2)
		local visual_l = math.max(1, math.ceil((vim.fn.strdisplaywidth(l) + 1) / math.max(1, max_w - 2)))
		total_visual_lines = total_visual_lines + visual_l
	end

	local width = math.max(10, math.min(max_line_len, max_w))
	local height = math.max(1, math.min(total_visual_lines, max_h))

	local top_down = M._opts.top_down ~= false
	local target_row = top_down and 1 or (vim.o.lines - 2)
	for _, item in ipairs(M.active_wins) do
		target_row = top_down and (target_row + item.height + 1) or (target_row - item.height - 1)
	end
	if not top_down then
		target_row = target_row - height
	end

	local target_col = math.max(0, vim.o.columns - width - 2)
	local static = M._opts.stages == "static"
	local start_col = static and target_col or vim.o.columns

	local win_opts = {
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
	}

	local ok_win, win = pcall(vim.api.nvim_open_win, buf, false, win_opts)
	if not ok_win or not win or not vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_echo({ { string.format("[%s] %s", title, msg_str), hl } }, true, {})
		return
	end

	pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
	pcall(vim.api.nvim_set_option_value, "linebreak", true, { win = win })
	pcall(vim.api.nvim_win_set_option, win, "winblend", static and 15 or 80)
	for i, line in ipairs(lines) do
		local _ = line
		if i == 1 and title ~= "" then
			pcall(vim.api.nvim_buf_add_highlight, buf, -1, hl, 0, 0, -1)
		end
	end

	local win_item = { win = win, buf = buf, width = width, height = height, current_row = target_row, current_col = start_col }
	table.insert(M.active_wins, win_item)

	if M._opts.on_open then
		pcall(M._opts.on_open, win)
	end

	if not static then
		local anim_steps = 6
		local anim_step = 0
		local anim_timer = uv.new_timer()
		anim_timer:start(0, 20, vim.schedule_wrap(function()
			if anim_timer:is_closing() then
				return
			end
			anim_step = anim_step + 1
			local t = math.min(1.0, anim_step / anim_steps)
			local factor = ease_in_out(t)
			local animated_col = math.floor(start_col - (start_col - target_col) * factor + 0.5)
			local blend = math.floor(80 - (80 - 15) * factor + 0.5)
			win_item.current_col = animated_col
			if vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_set_config, win, {
					relative = "editor",
					row = math.max(0, win_item.current_row),
					col = math.max(0, animated_col),
					focusable = false,
					noautocmd = true,
				})
				pcall(vim.api.nvim_win_set_option, win, "winblend", math.max(0, blend))
			end
			if anim_step >= anim_steps then
				safe_close_timer(anim_timer)
			end
		end))
	end

	local timeout = opts.timeout or M._opts.timeout or 3000
	if timeout == false then
		return
	end

	vim.defer_fn(function()
		if not (win and vim.api.nvim_win_is_valid(win)) then
			return
		end
		if static then
			pcall(vim.api.nvim_win_close, win, true)
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
			return
		end

		local exit_steps = 5
		local exit_step = 0
		local exit_timer = uv.new_timer()
		local exit_start_col = win_item.current_col or target_col
		local exit_end_col = vim.o.columns

		exit_timer:start(0, 20, vim.schedule_wrap(function()
			if exit_timer:is_closing() then
				return
			end
			exit_step = exit_step + 1
			local t = math.min(1.0, exit_step / exit_steps)
			local factor = ease_in_out(t)
			local animated_col = math.floor(exit_start_col + (exit_end_col - exit_start_col) * factor + 0.5)
			local blend = math.floor(15 + (90 - 15) * factor + 0.5)

			if vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_set_config, win, {
					relative = "editor",
					row = math.max(0, win_item.current_row),
					col = animated_col,
					focusable = false,
					noautocmd = true,
				})
				pcall(vim.api.nvim_win_set_option, win, "winblend", math.min(100, blend))
			end

			if exit_step >= exit_steps then
				safe_close_timer(exit_timer)
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
		end))
	end, timeout)
end

--- Configures the engine. Mirrors nvim-notify's `setup(opts)`.
--- @param opts table|nil
function M.setup(opts)
	M._opts = opts or {}
end

setmetatable(M, {
	__call = function(self, msg, level, opts)
		return self.notify(msg, level, opts)
	end,
})

return M
