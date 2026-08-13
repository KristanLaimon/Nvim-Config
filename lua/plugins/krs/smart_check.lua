-- ============================================================================
-- 🦊 KRS PLUGIN: Ultra-Fast Smart File Check & Real-Time Auto-Reload Manager
-- ============================================================================
-- PERFORMANCE & ZERO-OVERHEAD DESIGN:
-- 1. In-Memory State Caching: `vim.b[bufnr]._krs_is_deleted` caches deletion status
--    so tabline/bufferline rendering performs ZERO synchronous disk stat calls.
-- 2. Focus-Aware Lifecycle: Timer completely STOPS when Neovim loses window focus,
--    ensuring ZERO background CPU or disk I/O when working in other applications.
-- 3. Smart Debouncing & Throttling: `checktime` is throttled to at most once per 1.2s
--    and ONLY executes when active file buffers are listed.
-- 4. Event-Driven Auto-Reload: Instantly updates state on `FocusGained`, `BufEnter`,
--    `CursorHold`, and `BufWritePost`.
-- ============================================================================

local M = {}

local uv = vim.uv or vim.loop
local is_focused = true
local check_timer = nil
local last_check_time = 0

-- Fast in-memory check used by bufferline.nvim (0 disk I/O during tab rendering)
_G.Is_File_Deleted = function(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not bufnr or bufnr == 0 then
		bufnr = vim.api.nvim_buf_get_name and vim.api.nvim_get_current_buf() or 0
	end
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local cached = vim.b[bufnr]._krs_is_deleted
	if cached ~= nil then
		return cached
	end
	return M.update_buf_state(bufnr)
end

-- Update cached deletion state for a single buffer
function M.update_buf_state(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= "" then
		vim.b[bufnr]._krs_is_deleted = false
		return false
	end

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or path:match("^%a[%a%d+.-]+://") or path:match("^node:") then
		vim.b[bufnr]._krs_is_deleted = false
		return false
	end

	local is_deleted = (uv.fs_stat(path) == nil)
	local prev_state = vim.b[bufnr]._krs_is_deleted
	vim.b[bufnr]._krs_is_deleted = is_deleted

	if prev_state ~= nil and prev_state ~= is_deleted then
		pcall(vim.cmd, "redrawtabline")
	end
	return is_deleted
end

-- Check all active file buffers with throttling
function M.check_all_buffers(force)
	local now = uv.now()
	if not force and (now - last_check_time) < 1200 then
		return
	end
	last_check_time = now

	local bufs = vim.api.nvim_list_bufs()
	local file_bufs_count = 0
	local state_changed = false

	for _, b in ipairs(bufs) do
		if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "" and vim.fn.buflisted(b) == 1 then
			local name = vim.api.nvim_buf_get_name(b)
			if name ~= "" and not name:match("^%a[%a%d+.-]+://") and not name:match("^node:") then
				file_bufs_count = file_bufs_count + 1
				local prev = vim.b[b]._krs_is_deleted
				local curr = M.update_buf_state(b)
				if prev ~= nil and prev ~= curr then
					state_changed = true
				end
			end
		end
	end

	if file_bufs_count > 0 then
		pcall(vim.cmd, "checktime")
	end

	if state_changed then
		pcall(vim.cmd, "redrawtabline")
	end
end

-- Timer lifecycle control (Focus-aware)
local function stop_timer()
	if check_timer then
		check_timer:stop()
	end
end

local function start_timer()
	if not is_focused then
		return
	end
	if not check_timer then
		check_timer = uv.new_timer()
	end
	check_timer:stop()
	check_timer:start(
		2000,
		2000,
		vim.schedule_wrap(function()
			if is_focused then
				local mode = vim.api.nvim_get_mode().mode
				if not mode:find("^c") and not mode:find("^t") then
					M.check_all_buffers(false)
				end
			else
				stop_timer()
			end
		end)
	)
end

function M.setup()
	vim.opt.autoread = true

	local group = vim.api.nvim_create_augroup("KRSSmartCheckAutoRead", { clear = true })

	-- Focus Gained: Resume timer & force immediate check
	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			is_focused = true
			M.check_all_buffers(true)
			start_timer()
		end,
	})

	-- Focus Lost: Freeze timer completely (0% background CPU)
	vim.api.nvim_create_autocmd("FocusLost", {
		group = group,
		callback = function()
			is_focused = false
			stop_timer()
		end,
	})

	-- User interaction & buffer switch events (throttled)
	vim.api.nvim_create_autocmd(
		{ "BufEnter", "BufWritePost", "CursorHold", "CursorHoldI", "WinEnter", "TermClose" },
		{
			group = group,
			callback = function()
				if is_focused then
					local mode = vim.api.nvim_get_mode().mode
					if not mode:find("^c") and not mode:find("^t") then
						M.check_all_buffers(false)
					end
				end
			end,
		}
	)

	-- Redraw tabline when shell detects file change/deletion
	vim.api.nvim_create_autocmd("FileChangedShellPost", {
		group = group,
		callback = function()
			pcall(vim.cmd, "redrawtabline")
		end,
	})

	-- Initial startup check & timer start
	M.check_all_buffers(true)
	start_timer()
end

_G.SmartCheck = M

M.setup()

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_smart_check",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})
