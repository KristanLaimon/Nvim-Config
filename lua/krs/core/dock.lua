-- ============================================================================
-- krs.core.dock -- The bottom dock shared by terminals and task outputs.
-- ============================================================================
-- WHAT THE DOCK IS
--   One horizontal strip at the bottom of the editor, split vertically between
--   the multi-terminal (LEFT) and task outputs (RIGHT). Both plugins used to
--   carry their own copy of this window-hunting logic, and the copies disagreed
--   about which side each pane belonged on.
--
-- THE RULE
--   Terminals sit left of task outputs. `enforce_order()` swaps them back when a
--   new split lands on the wrong side, and both plugins call it after opening.
--
-- USAGE
--   local dock = require("krs.core.dock")
--   local win = dock.open({ prefer = "terminal", height = 10 })
--   local task_win, term_win = dock.find()
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

--- Filetype marking a task-output buffer, alongside the `krs_is_task` flag.
M.task_filetype = "TaskRunner"

--- Height, in lines, of a fresh bottom split when the dock does not exist yet.
M.default_height = 12

-- ---------------------------------------------------------------------------
-- Classification
-- ---------------------------------------------------------------------------

--- Classifies a window as task output, terminal, or neither.
--- A task output IS a terminal buffer, so the task test comes first.
---
--- @param win integer Window handle.
--- @return boolean is_task
--- @return boolean is_terminal
function M.classify(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false, false
	end

	local buf = vim.api.nvim_win_get_buf(win)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false, false
	end

	local is_task = (vim.b[buf].krs_is_task or vim.bo[buf].filetype == M.task_filetype) and true or false
	local is_term = ((vim.bo[buf].buftype == "terminal" and not is_task) or vim.b[buf].krs_is_multi_term) and true
		or false
	return is_task, is_term
end

--- Finds the first task-output window and the first terminal window.
--- @return integer|nil task_win
--- @return integer|nil term_win
function M.find()
	local task_win, term_win
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local is_task, is_term = M.classify(win)
		if is_task and not task_win then
			task_win = win
		elseif is_term and not term_win then
			term_win = win
		end
	end
	return task_win, term_win
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

--- Puts the terminal back on the left of the task output when a split landed on
--- the wrong side. Focus is restored to whatever window the user was in.
function M.enforce_order()
	local task_win, term_win = M.find()
	if not (task_win and term_win) then
		return
	end

	local term_col = vim.api.nvim_win_get_position(term_win)[2]
	local task_col = vim.api.nvim_win_get_position(task_win)[2]
	if term_col <= task_col then
		return
	end

	local cur_win = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(task_win)
	vim.cmd("wincmd x")
	if vim.api.nvim_win_is_valid(cur_win) then
		pcall(vim.api.nvim_set_current_win, cur_win)
	end
end

--- Opens a window inside the dock and returns it.
--- With the dock already on screen the new window is split beside the existing
--- pane, on the side the caller belongs to; otherwise the dock itself is created
--- as a bottom split.
---
--- @param opts table|nil Options:
---   prefer string  "terminal" or "task" (default). Decides which side to take.
---   height number  Height of a freshly created dock. Default `M.default_height`.
--- @return integer win New window handle.
function M.open(opts)
	opts = opts or {}
	local task_win, term_win = M.find()

	if opts.prefer == "terminal" then
		if term_win then
			vim.api.nvim_set_current_win(term_win)
			vim.cmd("rightbelow vsplit")
		elseif task_win then
			-- Land on the left of the task output rather than beyond it.
			vim.api.nvim_set_current_win(task_win)
			vim.cmd("leftabove vsplit")
		else
			vim.cmd("botright " .. (opts.height or M.default_height) .. "split")
		end
	else
		local anchor = task_win or term_win
		if anchor then
			vim.api.nvim_set_current_win(anchor)
			vim.cmd("rightbelow vsplit")
		else
			vim.cmd("botright " .. (opts.height or M.default_height) .. "split")
		end
	end

	local win = vim.api.nvim_get_current_win()
	M.enforce_order()
	return win
end

--- Strips line numbers and signs from a dock window.
--- @param win integer Window handle.
function M.style(win)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
end

return M
