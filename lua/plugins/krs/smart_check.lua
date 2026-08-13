-- ============================================================================
-- 🦊 KRS PLUGIN: Smart File Check & Real-Time Auto-Reload Manager
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Enables `autoread` (`vim.opt.autoread = true`) to allow auto-reloading.
-- 2. Listens to editor events (`FocusGained`, `BufEnter`, `CursorHold`, `CursorHoldI`,
--    `WinEnter`, `TermClose`) to trigger `checktime` for disk change detection.
-- 3. Runs a background timer every 1000ms so idle buffers reload externally modified
--    files in real-time without needing to close/re-open or press keys.
-- 4. Triggers tabline redraw when files are modified or deleted on disk.
-- 5. Exportable helper `_G.Is_File_Deleted(bufnr)` used by bufferline.nvim to
--    prepend `[D]` to tab titles when files are deleted on disk.
-- ============================================================================

local M = {}

_G.Is_File_Deleted = function(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" or path:match("^%a[%a%d+.-]+://") or path:match("^node:") then
		return false
	end
	local uv = vim.uv or vim.loop
	return uv.fs_stat(path) == nil
end

local check_timer = nil

function M.setup()
	vim.opt.autoread = true

	local group = vim.api.nvim_create_augroup("KRSSmartCheckAutoRead", { clear = true })

	-- Trigger checktime on user interactions & window focus
	vim.api.nvim_create_autocmd(
		{ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "WinEnter", "TermClose" },
		{
			group = group,
			callback = function()
				local mode = vim.api.nvim_get_mode().mode
				if not mode:find("^c") and not mode:find("^t") then
					pcall(vim.cmd, "checktime")
				end
			end,
		}
	)

	-- Redraw tabline when shell detects file change/deletion
	vim.api.nvim_create_autocmd({ "FileChangedShellPost" }, {
		group = group,
		callback = function()
			pcall(vim.cmd, "redrawtabline")
		end,
	})

	-- Background timer for real-time external change detection (every 1 second)
	if not check_timer then
		local uv = vim.uv or vim.loop
		check_timer = uv.new_timer()
		check_timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				local mode = vim.api.nvim_get_mode().mode
				if not mode:find("^c") and not mode:find("^t") then
					pcall(vim.cmd, "checktime")
				end
			end)
		)
	end
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
