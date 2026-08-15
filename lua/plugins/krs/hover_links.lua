-- ============================================================================
-- KRS PLUGIN: Hover Doc Links -- navigate file:/// and web links in hover popups
-- ============================================================================
-- WHAT IT DOES
--   * Triggers or focuses LSP hover documentation when `K` or `Shift+K` is pressed.
--   * When inside the hover float, caret movement + `<CR>` (Enter), `gx` or `K`
--     follows markdown links `[label](target)` and raw URLs (`file://...`, `https://...`).
--   * Local file links (`file:///...#line,col` or `:line:col`) jump directly to that
--     file and position in the main editor window.
--   * Web links (`http://...` or `https://...`) open in the system default web browser.
-- ============================================================================

local path = require("krs.core.path")

local M = {}

M.settings = {
	border = "rounded",
}

--- Checks if a window handle is a floating window.
--- @param winid integer|nil Window handle.
--- @return boolean
local function is_float_win(winid)
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		return false
	end
	local cfg = vim.api.nvim_win_get_config(winid)
	return cfg.relative ~= nil and cfg.relative ~= ""
end

--- Finds an active floating window associated with the current buffer or hover preview.
--- @return integer|nil winid
local function find_hover_float_win()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if is_float_win(win) then
			local b = vim.api.nvim_win_get_buf(win)
			local ft = vim.bo[b].filetype
			if ft == "markdown" or ft == "lspinfo" or ft == "" then
				return win
			end
		end
	end
	return nil
end

--- Extracts all links from a string line.
--- @param line string
--- @return table[] links List of { start_col, end_col, label, target }
local function parse_links_in_line(line)
	local links = {}

	-- 1. Markdown links: [label](target)
	local s_pos = 1
	while true do
		local m_start, m_end, label, target = line:find("(%[[^%]]+%]%(([^%)]+)%))", s_pos)
		if not m_start then
			break
		end
		table.insert(links, {
			start_col = m_start,
			end_col = m_end,
			label = label,
			target = target,
		})
		s_pos = m_end + 1
	end

	-- 2. Raw URLs: http(s):// or file://
	local patterns = { "https?://%S+", "file://%S+" }
	for _, pat in ipairs(patterns) do
		s_pos = 1
		while true do
			local u_start, u_end, target = line:find("(" .. pat .. ")", s_pos)
			if not u_start then
				break
			end

			-- Strip trailing punctuation if accidentally matched (like trailing paren or period)
			target = target:gsub("[%),.]+$", "")

			local inside = false
			for _, l in ipairs(links) do
				if u_start >= l.start_col and u_end <= l.end_col then
					inside = true
					break
				end
			end
			if not inside then
				table.insert(links, {
					start_col = u_start,
					end_col = u_end,
					label = target,
					target = target,
				})
			end
			s_pos = u_end + 1
		end
	end

	return links
end

--- Opens a web URL in the system browser.
--- @param url string
local function open_web_url(url)
	local ok = pcall(vim.ui.open, url)
	if not ok then
		if vim.fn.has("win32") == 1 then
			vim.fn.jobstart({ "cmd", "/c", "start", "", url })
		elseif vim.fn.has("mac") == 1 then
			vim.fn.jobstart({ "open", url })
		else
			vim.fn.jobstart({ "xdg-open", url })
		end
	end
	vim.notify("🌐 Opening web link: " .. url, vim.log.levels.INFO, { title = "LSP Hover Link" })
end

--- Opens a local file URL or file path at the given line/column.
--- @param target string file:/// path or relative path with optional #line,col or :line:col
--- @param hover_winid integer Hover float window handle to close.
local function open_local_file_link(target, hover_winid)
	local raw_path = target:gsub("^file:///", ""):gsub("^file://", "")
	-- On Windows file:///C:/... becomes /C:/...; strip leading slash for drive letters
	raw_path = raw_path:gsub("^/(%a:)", "%1")

	local clean_path = raw_path
	local target_line, target_col = 1, 1

	-- Try matching patterns: #2575,6 or #2575 or #L2575,6 or :2575:6 or :2575
	local p1, l1, c1 = raw_path:match("^(.-)#L?(%d+),?(%d*)$")
	if p1 then
		clean_path = p1
		target_line = tonumber(l1) or 1
		target_col = tonumber(c1) or 1
	else
		local p2, l2, c2 = raw_path:match("^(.-)#L?(%d+):?(%d*)$")
		if p2 then
			clean_path = p2
			target_line = tonumber(l2) or 1
			target_col = tonumber(c2) or 1
		else
			local p3, l3, c3 = raw_path:match("^(.-):(%d+):?(%d*)$")
			if p3 then
				clean_path = p3
				target_line = tonumber(l3) or 1
				target_col = tonumber(c3) or 1
			end
		end
	end

	clean_path = path.normalize(clean_path)
	local is_abs = (path.is_absolute and path.is_absolute(clean_path)) or (clean_path:sub(1, 1) == "/" or clean_path:match("^%a:") ~= nil)
	if not is_abs then
		clean_path = path.join(vim.fn.getcwd(), clean_path)
	end

	-- Close hover float window
	if hover_winid and vim.api.nvim_win_is_valid(hover_winid) then
		pcall(vim.api.nvim_win_close, hover_winid, true)
	end

	if vim.fn.filereadable(clean_path) ~= 1 then
		vim.notify("File not found: " .. clean_path, vim.log.levels.WARN, { title = "LSP Hover Link" })
		return
	end

	-- Open in current main window
	vim.cmd("edit " .. vim.fn.fnameescape(clean_path))
	pcall(vim.api.nvim_win_set_cursor, 0, { target_line, math.max(0, target_col - 1) })
	vim.notify("📂 Jumped to " .. vim.fn.fnamemodify(clean_path, ":t") .. ":" .. target_line .. ":" .. target_col, vim.log.levels.INFO, { title = "LSP Hover Link" })
end

--- Parses link at cursor inside the float window and executes jump.
function M.follow_link_at_cursor()
	local winid = vim.api.nvim_get_current_win()
	if not is_float_win(winid) then
		return
	end

	local bufnr = vim.api.nvim_win_get_buf(winid)
	local cursor = vim.api.nvim_win_get_cursor(winid)
	local row, col = cursor[1], cursor[2] + 1

	local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
	local line = lines[1] or ""

	local links = parse_links_in_line(line)

	-- If no links on current line, search whole buffer for links
	if #links == 0 then
		local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		for _, l in ipairs(all_lines) do
			local l_links = parse_links_in_line(l)
			if #l_links > 0 then
				links = l_links
				break
			end
		end
	end

	if #links == 0 then
		vim.notify("No links found on this line or doc", vim.log.levels.WARN, { title = "LSP Hover Link" })
		return
	end

	-- Select best link relative to cursor col
	local chosen = nil
	for _, link in ipairs(links) do
		if col >= link.start_col and col <= link.end_col then
			chosen = link
			break
		end
	end

	if not chosen then
		chosen = links[1]
	end

	local target = chosen.target
	if target:match("^https?://") or target:match("^www%.") then
		open_web_url(target)
	else
		open_local_file_link(target, winid)
	end
end

--- Closes hover float window.
function M.close_hover()
	local winid = vim.api.nvim_get_current_win()
	if is_float_win(winid) then
		pcall(vim.api.nvim_win_close, winid, true)
	end
end

--- Attaches keymaps to a hover float buffer.
--- @param bufnr integer
--- @param winid integer
function M.attach_hover_keymaps(bufnr, winid)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local opts = { buffer = bufnr, noremap = true, silent = true }

	vim.keymap.set("n", "<CR>", M.follow_link_at_cursor, opts)
	vim.keymap.set("n", "gx", M.follow_link_at_cursor, opts)
	vim.keymap.set("n", "K", M.follow_link_at_cursor, opts)
	vim.keymap.set("n", "q", M.close_hover, opts)
	vim.keymap.set("n", "<Esc>", M.close_hover, opts)
end

--- Shows hover or focuses floating window if already open.
function M.show_or_focus_hover()
	local current_win = vim.api.nvim_get_current_win()

	-- If already in a float window
	if is_float_win(current_win) then
		M.follow_link_at_cursor()
		return
	end

	-- If a hover float is open, move cursor into it
	local float_win = find_hover_float_win()
	if float_win then
		vim.api.nvim_set_current_win(float_win)
		return
	end

	-- Otherwise trigger hover
	pcall(function()
		vim.lsp.buf.hover({ border = M.settings.border, focusable = true })
	end)
end

--- Initializes LSP hover handler wrapper.
function M.setup()
	local orig_hover = vim.lsp.handlers["textDocument/hover"]
	if orig_hover then
		vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
			config = config or {}
			config.border = config.border or M.settings.border
			config.focusable = true
			local bufnr, winid = orig_hover(err, result, ctx, config)
			if winid and vim.api.nvim_win_is_valid(winid) then
				local buf = vim.api.nvim_win_get_buf(winid)
				M.attach_hover_keymaps(buf, winid)
			end
			return bufnr, winid
		end
	end
end

M.setup()

return setmetatable({
	name = "krs_hover_links",
	dir = require("krs.core.lazyspec").for_module(),
	lazy = false,
	config = M.setup,
}, { __index = M })
