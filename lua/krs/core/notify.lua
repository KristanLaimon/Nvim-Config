-- ============================================================================
-- KRS CORE: Non-Blocking Toast Notification Engine with Ease-In-Out Animation
-- ============================================================================
-- Features:
--   * Cubic Ease-In-Out smooth slide-in entry & slide-out exit animations.
--   * Auto slide-UP queue repositioning when the top toast disappears.
--   * Strict `focusable = false` on every frame -- guaranteed NEVER to steal focus.
--   * Duplicate notification throttling to prevent open-file toast spam.
-- ============================================================================

local M = {}

M.active_wins = {}
M.last_messages = {}

local uv = vim.uv or vim.loop

--- Cubic ease-in-out function (0 <= t <= 1).
--- @param t number Progress from 0.0 to 1.0
--- @return number Smoothly interpolated value between 0.0 and 1.0
local function ease_in_out(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2
	end
end

--- Smoothly recalculates and animates remaining active windows sliding UP into place.
function M.reposition_wins()
	local current_row = 1
	for _, item in ipairs(M.active_wins) do
		if item.win and vim.api.nvim_win_is_valid(item.win) then
			local target_row = current_row
			current_row = current_row + item.height + 1
			item.target_row = target_row

			-- Animate row slide-up over ~150ms
			local start_row = item.current_row or target_row
			if start_row ~= target_row then
				local steps = 5
				local step = 0
				local timer = uv.new_timer()
				timer:start(0, 25, vim.schedule_wrap(function()
					step = step + 1
					local t = math.min(1.0, step / steps)
					local factor = ease_in_out(t)
					local animated_row = math.floor(start_row + (target_row - start_row) * factor + 0.5)
					item.current_row = animated_row

					if item.win and vim.api.nvim_win_is_valid(item.win) then
						pcall(vim.api.nvim_win_set_config, item.win, {
							relative = "editor",
							row = math.max(0, animated_row),
							col = math.max(0, item.current_col or (vim.o.columns - item.width - 2)),
							focusable = false,
							noautocmd = true,
						})
					end

					if step >= steps then
						timer:stop()
						timer:close()
					end
				end))
			end
		end
	end
end

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

	-- Throttle duplicate messages within 2 seconds to prevent notification spam
	local now = uv.now()
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

	local copy_fn = function()
		vim.fn.setreg("+", msg_str)
		vim.fn.setreg("*", msg_str)
		vim.api.nvim_echo({ { "📋 Notification text copied to clipboard!", "DiagnosticInfo" } }, true, {})
	end
	vim.keymap.set({ "n", "v", "i" }, "<LeftMouse>", copy_fn, { buffer = buf, silent = true, noremap = true })
	vim.keymap.set({ "n", "v", "i" }, "<2-LeftMouse>", copy_fn, { buffer = buf, silent = true, noremap = true })

	-- Compute geometry
	local is_mobile = false
	local env_ok, env_mod = pcall(require, "krs.core.environment")
	if env_ok then
		local env = env_mod.detect()
		is_mobile = env.is_mobile or env.is_termux or env.is_proot
	else
		is_mobile = vim.env.TERMUX_VERSION ~= nil or vim.fn.isdirectory("/data/data/com.termux") == 1 or (vim.o.columns or 80) < 72
	end

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l + 2)
	end
	local max_w = is_mobile and math.max(20, math.min(30, math.floor((vim.o.columns or 80) * 0.55))) or math.floor((vim.o.columns or 80) * 0.7)
	width = math.min(width, max_w)
	local max_h = is_mobile and 3 or 10
	local height = math.min(#lines, max_h)

	-- Calculate initial row in queue
	local target_row = 1
	for _, item in ipairs(M.active_wins) do
		target_row = target_row + item.height + 1
	end

	local target_col = math.max(0, vim.o.columns - width - 2)
	local start_col = vim.o.columns -- Start off-screen right

	-- Open floating window initially at off-screen position with focusable = false
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, target_row),
		col = start_col,
		style = "minimal",
		border = "rounded",
		focusable = false, -- CRITICAL: Never steal keyboard/touch input!
		noautocmd = true,
		zindex = 10,
	}

	local ok_win, win = pcall(vim.api.nvim_open_win, buf, false, win_opts)
	if not ok_win or not win or not vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_echo({ { string.format("[%s] %s", title, msg_str), hl } }, true, {})
		return
	end

	pcall(vim.api.nvim_win_set_option, win, "winblend", 80)

	local win_item = {
		win = win,
		buf = buf,
		width = width,
		height = height,
		current_row = target_row,
		current_col = start_col,
	}
	table.insert(M.active_wins, win_item)

	-- 1. Entry Animation: Ease-In-Out Slide from right to target_col
	local anim_steps = 6
	local anim_step = 0
	local anim_timer = uv.new_timer()
	anim_timer:start(0, 25, vim.schedule_wrap(function()
		anim_step = anim_step + 1
		local t = math.min(1.0, anim_step / anim_steps)
		local factor = ease_in_out(t)
		local animated_col = math.floor(start_col - (start_col - target_col) * factor + 0.5)
		local blend = math.floor(80 - (80 - 15) * factor + 0.5)

		win_item.current_col = animated_col

		if win and vim.api.nvim_win_is_valid(win) then
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
			anim_timer:stop()
			anim_timer:close()
		end
	end))

	-- 2. Auto-dismiss & Exit Animation (Slide out right + Slide remaining up)
	local timeout = opts.timeout or (is_mobile and 1800 or 2500)
	vim.defer_fn(function()
		local exit_steps = 5
		local exit_step = 0
		local exit_timer = uv.new_timer()

		local exit_start_col = win_item.current_col or target_col
		local exit_end_col = vim.o.columns

		exit_timer:start(0, 25, vim.schedule_wrap(function()
			exit_step = exit_step + 1
			local t = math.min(1.0, exit_step / exit_steps)
			local factor = ease_in_out(t)
			local animated_col = math.floor(exit_start_col + (exit_end_col - exit_start_col) * factor + 0.5)
			local blend = math.floor(15 + (90 - 15) * factor + 0.5)

			if win and vim.api.nvim_win_is_valid(win) then
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
				exit_timer:stop()
				exit_timer:close()

				-- Close window and buffer
				if win and vim.api.nvim_win_is_valid(win) then
					pcall(vim.api.nvim_win_close, win, true)
				end
				if buf and vim.api.nvim_buf_is_valid(buf) then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end

				-- Remove item from active_wins
				for idx, item in ipairs(M.active_wins) do
					if item.win == win then
						table.remove(M.active_wins, idx)
						break
					end
				end

				-- Trigger slide-UP queue repositioning for all remaining toasts!
				M.reposition_wins()
			end
		end))
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
