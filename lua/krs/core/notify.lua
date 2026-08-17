-- ============================================================================
-- KRS CORE: Bulletproof Non-Blocking Toast Notification Engine
-- ============================================================================
-- Replaces `vim.notify` with a 100% focus-safe, freeze-proof notification UI.
-- Guaranteed NEVER to steal keyboard/touch input or freeze Neovim on mobile/desktop.
-- ============================================================================

local M = {}

M.active_wins = {}
M.last_messages = {}

--- Clears all active floating notifications.
function M.dismiss_all()
	for _, item in ipairs(M.active_wins) do
		if item.win and vim.api.nvim_win_is_valid(item.win) then
			pcall(vim.api.nvim_win_close, item.win, true)
		end
		if item.buf and vim.api.nvim_buf_is_valid(item.buf) then
			pcall(vim.api.nvim_buf_delete, item.buf, { force = true })
		end
	end
	M.active_wins = {}
end

--- Custom bulletproof vim.notify implementation.
--- @param msg string|table Message to display
--- @param level number|nil Log level (vim.log.levels.INFO/WARN/ERROR)
--- @param opts table|nil Extra options (title, timeout, etc.)
function M.notify(msg, level, opts)
	if not msg or msg == "" then
		return
	end

	opts = opts or {}
	level = level or vim.log.levels.INFO
	local msg_str = type(msg) == "table" and table.concat(msg, "\n") or tostring(msg)

	-- Throttle duplicate messages within 2 seconds to prevent notification spam on file open
	local now = (vim.uv or vim.loop).now()
	if M.last_messages[msg_str] and (now - M.last_messages[msg_str]) < 2000 then
		return
	end
	M.last_messages[msg_str] = now

	-- Format level icon
	local icon = "ℹ️ "
	local hl = "DiagnosticInfo"
	if level == vim.log.levels.WARN then
		icon = "⚠️ "
		hl = "DiagnosticWarn"
	elseif level == vim.log.levels.ERROR then
		icon = "❌ "
		hl = "DiagnosticError"
	end

	local title = opts.title or "Neovim"
	local lines = {}
	table.insert(lines, string.format("%s %s", icon, title))
	table.insert(lines, string.rep("─", math.max(20, #title + 4)))
	for line in msg_str:gmatch("[^\r\n]+") do
		table.insert(lines, " " .. line)
	end

	-- Create unlisted scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "notify"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Compute geometry
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l + 2)
	end
	width = math.min(width, math.floor(vim.o.columns * 0.7))
	local height = #lines

	local row = 1 + #M.active_wins * (height + 1)
	local col = vim.o.columns - width - 2

	-- Open floating window with strict focusable = false
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, row),
		col = math.max(0, col),
		style = "minimal",
		border = "rounded",
		focusable = false, -- CRITICAL: Never steal keyboard/touch input!
		noautocmd = true,
		zindex = 10,
	}

	local ok_win, win = pcall(vim.api.nvim_open_win, buf, false, win_opts)
	if not ok_win or not win or not vim.api.nvim_win_is_valid(win) then
		-- Fallback to standard echo if window creation fails
		vim.api.nvim_echo({ { string.format("[%s] %s", title, msg_str), hl } }, true, {})
		return
	end

	pcall(vim.api.nvim_win_set_option, win, "winblend", 15)

	local win_item = { win = win, buf = buf }
	table.insert(M.active_wins, win_item)

	-- Auto dismiss after 2.5 seconds
	local timeout = opts.timeout or 2500
	vim.defer_fn(function()
		if win and vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
		if buf and vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		for i, item in ipairs(M.active_wins) do
			if item.win == win then
				table.remove(M.active_wins, i)
				break
			end
		end
	end, timeout)
end

function M.setup()
	vim.notify = M.notify

	vim.api.nvim_create_user_command("NotifyDismiss", M.dismiss_all, { desc = "Dismiss all floating toast notifications" })
	vim.api.nvim_create_user_command("ClearToasts", M.dismiss_all, { desc = "Dismiss all floating toast notifications" })

	vim.keymap.set("n", "<leader>nd", M.dismiss_all, { desc = "Dismiss active notifications" })
	vim.keymap.set("n", "<leader>un", M.dismiss_all, { desc = "Dismiss active notifications" })
end

return M
