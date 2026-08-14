-- ============================================================================
-- krs.core.ui -- Floating window and scratch buffer factory.
-- ============================================================================
-- WHY THIS EXISTS
--   Every KRS modal repeated the same 15 lines: create a scratch buffer, set
--   `buftype`/`bufhidden`, compute a centered row/col, open a rounded float, then
--   map `q`/`<Esc>` to close. Centering arithmetic was copy-pasted with slightly
--   different clamping, so a small terminal broke some modals and not others.
--
-- DESIGN
--   `float()` returns `buf, win` and nothing else -- callers keep full control of
--   content, highlights and extra mappings. This module owns geometry and the
--   scratch-buffer boilerplate; it deliberately owns no application state.
--
-- USAGE
--   local ui = require("krs.core.ui")
--   local buf, win = ui.float({ lines = lines, title = " Tasks ", width = 0.6 })
--   ui.close_on_keys(buf, win)
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Configuration -- defaults for every KRS float
-- ---------------------------------------------------------------------------

--- Default window border style. Any `nvim_open_win` border value works.
M.border = "rounded"

--- Keys that dismiss a float when `close_on_keys` is used.
M.close_keys = { "q", "<Esc>" }

--- Minimum row/col so a float never lands off-screen on small terminals.
M.min_offset = 1

-- ---------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------

--- Resolves a size given either an absolute cell count (>= 1) or a fraction of
--- the editor (0 < n < 1).
---
--- @param value number Absolute cells or fraction of `total`.
--- @param total number Editor width or height in cells.
--- @return integer size Size in cells, at least 1.
function M.resolve_size(value, total)
	if value > 0 and value < 1 then
		return math.max(math.floor(total * value), 1)
	end
	return math.max(math.floor(value), 1)
end

--- Computes centered `row`/`col` for a float of the given size.
---
--- @param width integer Float width in cells.
--- @param height integer Float height in cells.
--- @return integer row
--- @return integer col
function M.center(width, height)
	local row = math.max(math.floor(((vim.o.lines or 24) - height) / 2), M.min_offset)
	local col = math.max(math.floor(((vim.o.columns or 80) - width) / 2), M.min_offset)
	return row, col
end

-- ---------------------------------------------------------------------------
-- Buffers & windows
-- ---------------------------------------------------------------------------

--- Creates an unlisted scratch buffer, optionally filled with `lines`.
---
--- @param opts table|nil { lines?: string[], filetype?: string, modifiable?: boolean }
--- @return integer buf Buffer handle.
function M.scratch_buffer(opts)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	if opts.filetype then
		vim.bo[buf].filetype = opts.filetype
	end
	if opts.lines then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
	end
	vim.bo[buf].modifiable = opts.modifiable == true
	return buf
end

--- Opens a centered floating window over a scratch buffer.
---
--- @param opts table|nil Options:
---   lines      string[]  Initial content.
---   buf        integer   Existing buffer to reuse instead of creating one.
---   width      number    Cells, or a 0-1 fraction of the editor. Default 0.6.
---   height     number    Cells, or a 0-1 fraction of the editor. Defaults to `#lines`.
---   title      string    Window title, centered.
---   filetype   string    Buffer filetype, useful for syntax and autocmds.
---   focus      boolean   Enter the window. Default true.
---   modifiable boolean   Leave the buffer writable. Default false.
---   border     string    Overrides `M.border`.
--- @return integer buf Buffer handle.
--- @return integer win Window handle.
function M.float(opts)
	opts = opts or {}
	local buf = opts.buf
		or M.scratch_buffer({ lines = opts.lines, filetype = opts.filetype, modifiable = opts.modifiable })

	local width = M.resolve_size(opts.width or 0.6, vim.o.columns or 80)
	local height = M.resolve_size(opts.height or (opts.lines and #opts.lines) or 0.6, vim.o.lines or 24)
	local row, col = M.center(width, height)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = opts.border or M.border,
	}
	if opts.title then
		win_opts.title = opts.title
		win_opts.title_pos = "center"
	end

	local win = vim.api.nvim_open_win(buf, opts.focus ~= false, win_opts)
	return buf, win
end

--- Maps `M.close_keys` in `buf` to close `win` (and wipe the buffer).
---
--- @param buf integer Buffer handle.
--- @param win integer Window handle.
--- @param keys string[]|nil Overrides `M.close_keys`.
function M.close_on_keys(buf, win, keys)
	for _, key in ipairs(keys or M.close_keys) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end, { buffer = buf, nowait = true, silent = true })
	end
end

--- Closes a window if it is still valid. Safe to call with nil.
---
--- @param win integer|nil Window handle.
function M.close(win)
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
end

return M
