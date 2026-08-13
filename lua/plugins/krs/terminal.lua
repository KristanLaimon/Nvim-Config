-- ============================================================================
-- 🦊 KRS PLUGIN: Lazy Loading Multi-Terminal Manager
-- ============================================================================
-- 1. Manages 9 independent terminals (1-9) with Lazy Loading.
-- 2. <Alt + 1> .. <Alt + 9> selects and switches to terminal #n.
-- 3. <Ctrl + ;> / <Alt + ;> toggles open/hidden for currently SELECTED terminal.
-- 4. Supports clean navigation between code editor and terminals.
-- 5. Persistent terminal table & auto-sync prevents duplicate/detached terminals.
-- ============================================================================

local M = {}

-- Persist terminal table across config reloads
_G._krs_terminals = _G._krs_terminals or {}
local terminals = _G._krs_terminals

_G._krs_selected_terminal = _G._krs_selected_terminal or 1
local code_win = nil -- Origin code window to return with clean focus

-- Persisted terminal split height
local height_file = vim.fn.stdpath("state") .. "/terminal_height"

local function load_saved_height()
	local f = io.open(height_file, "r")
	if f then
		local content = f:read("*a")
		f:close()
		local h = tonumber(content)
		if h and h >= 3 and h <= 100 then
			return h
		end
	end
	return 10
end

local terminal_height = load_saved_height()

local function save_height(h)
	if type(h) == "number" and h >= 3 and h <= 100 and h ~= terminal_height then
		terminal_height = h
		local f = io.open(height_file, "w")
		if f then
			f:write(tostring(h))
			f:close()
		end
	end
end

vim.api.nvim_create_autocmd("WinResized", {
	group = vim.api.nvim_create_augroup("KrsTerminalHeightSaver", { clear = true }),
	callback = function()
		for _, winid in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(winid) then
				local bufnr = vim.api.nvim_win_get_buf(winid)
				if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
					save_height(vim.api.nvim_win_get_height(winid))
				end
			end
		end
	end,
})

local function terminal_open_cmd()
	local ok, wsl = pcall(require, "plugins.krs.wsl")
	local wsl_cmd = ok and wsl.shell_command_for_cwd(vim.fn.getcwd()) or nil
	return wsl_cmd and ("terminal " .. wsl_cmd) or "terminal"
end

local function is_valid_win(win)
	return win and type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
	return buf and type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function get_term(n)
	local t = terminals[n]
	if not t then
		t = { buf = nil, win = nil }
		terminals[n] = t
	end
	return t
end

local function sync_terminals()
	-- Clean up invalid references
	for n = 1, 9 do
		local t = terminals[n]
		if t then
			if t.win and not is_valid_win(t.win) then
				t.win = nil
			end
			if t.buf and not is_valid_buf(t.buf) then
				t.buf = nil
			end
		end
	end

	-- 1. Scan all active windows for terminal buffers
	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(winid) then
			local bufnr = vim.api.nvim_win_get_buf(winid)
			if vim.api.nvim_buf_is_valid(bufnr) then
				local term_num = vim.b[bufnr].krs_term_num
				if term_num and term_num >= 1 and term_num <= 9 then
					local t = get_term(term_num)
					t.buf = bufnr
					t.win = winid
				elseif vim.bo[bufnr].buftype == "terminal" and not vim.b[bufnr].krs_is_task then
					for n = 1, 9 do
						local t = get_term(n)
						if not is_valid_buf(t.buf) then
							t.buf = bufnr
							t.win = winid
							vim.b[bufnr].krs_term_num = n
							vim.b[bufnr].krs_is_multi_term = true
							break
						end
					end
				end
			end
		end
	end

	-- 2. Scan all valid buffers for hidden terminal buffers
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local term_num = vim.b[bufnr].krs_term_num
			if term_num and term_num >= 1 and term_num <= 9 then
				local t = get_term(term_num)
				if not is_valid_buf(t.buf) then
					t.buf = bufnr
				end
			elseif vim.bo[bufnr].buftype == "terminal" and not vim.b[bufnr].krs_is_task then
				for n = 1, 9 do
					local t = get_term(n)
					if not is_valid_buf(t.buf) then
						t.buf = bufnr
						vim.b[bufnr].krs_term_num = n
						vim.b[bufnr].krs_is_multi_term = true
						break
					end
				end
			end
		end
	end
end

local function get_active_terminal_win()
	sync_terminals()
	local sel_t = terminals[_G._krs_selected_terminal or 1]
	if sel_t and is_valid_win(sel_t.win) then
		return sel_t.win
	end
	for _, t in pairs(terminals) do
		if is_valid_win(t.win) then
			return t.win
		end
	end
	return nil
end

function M.get_selected_terminal()
	return _G._krs_selected_terminal or 1
end

function M.select_terminal(n)
	sync_terminals()
	_G._krs_selected_terminal = n
	local t = get_term(n)
	local current_win = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	if not active_win or current_win ~= active_win then
		code_win = current_win
	end

	if is_valid_win(active_win) then
		t.win = active_win
		if is_valid_buf(t.buf) then
			vim.api.nvim_win_set_buf(t.win, t.buf)
		else
			vim.api.nvim_set_current_win(t.win)
			vim.cmd(terminal_open_cmd())
			t.buf = vim.api.nvim_get_current_buf()
			vim.bo[t.buf].buflisted = false
			vim.b[t.buf].krs_term_num = n
			vim.b[t.buf].krs_is_multi_term = true
		end
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
	else
		M.open_terminal(n)
	end

	vim.notify("🖥️ Terminal #" .. n .. " active", vim.log.levels.INFO, { title = "Multi-Terminal" })
end

local function enforce_bottom_layout()
	local term_win = nil
	local task_win = nil

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) then
				local bt = vim.bo[buf].buftype
				local ft = vim.bo[buf].filetype
				local is_task = vim.b[buf].krs_is_task or ft == "TaskRunner"
				local is_term = (bt == "terminal" and not is_task) or vim.b[buf].krs_is_multi_term
				if is_term and not term_win then
					term_win = win
				elseif is_task and not task_win then
					task_win = win
				end
			end
		end
	end

	if term_win and task_win then
		local term_pos = vim.api.nvim_win_get_position(term_win)
		local task_pos = vim.api.nvim_win_get_position(task_win)

		if term_pos[2] > task_pos[2] then
			local cur_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(task_win)
			vim.cmd("wincmd x")
			if vim.api.nvim_win_is_valid(cur_win) then
				pcall(vim.api.nvim_set_current_win, cur_win)
			end
		end
	end
end
M.enforce_bottom_layout = enforce_bottom_layout

local function open_or_attach_bottom_win(height)
	local existing_term_win = nil
	local existing_task_win = nil

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) then
				local bt = vim.bo[buf].buftype
				local ft = vim.bo[buf].filetype
				local is_task = vim.b[buf].krs_is_task or ft == "TaskRunner"
				local is_term = (bt == "terminal" and not is_task) or vim.b[buf].krs_is_multi_term
				if is_term and not existing_term_win then
					existing_term_win = win
				elseif is_task and not existing_task_win then
					existing_task_win = win
				end
			end
		end
	end

	local new_win
	if existing_term_win then
		vim.api.nvim_set_current_win(existing_term_win)
		vim.cmd("rightbelow vsplit")
		new_win = vim.api.nvim_get_current_win()
	elseif existing_task_win then
		vim.api.nvim_set_current_win(existing_task_win)
		vim.cmd("leftabove vsplit")
		new_win = vim.api.nvim_get_current_win()
	else
		vim.cmd("botright " .. height .. "split")
		new_win = vim.api.nvim_get_current_win()
	end

	enforce_bottom_layout()
	return new_win
end

function M.open_terminal(n)
	sync_terminals()
	n = n or _G._krs_selected_terminal or 1
	_G._krs_selected_terminal = n
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	if current ~= active_win then
		code_win = current
	end

	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	if is_valid_win(active_win) then
		t.win = active_win
		if is_valid_buf(t.buf) then
			vim.api.nvim_win_set_buf(t.win, t.buf)
		else
			vim.api.nvim_set_current_win(t.win)
			vim.cmd(terminal_open_cmd())
			t.buf = vim.api.nvim_get_current_buf()
			vim.bo[t.buf].buflisted = false
			vim.b[t.buf].krs_term_num = n
			vim.b[t.buf].krs_is_multi_term = true
		end
		vim.cmd("startinsert")
		return
	end

	t.win = open_or_attach_bottom_win(terminal_height)

	if is_valid_buf(t.buf) then
		vim.api.nvim_win_set_buf(t.win, t.buf)
	else
		vim.cmd(terminal_open_cmd())
		t.buf = vim.api.nvim_get_current_buf()
		vim.bo[t.buf].buflisted = false
		vim.b[t.buf].krs_term_num = n
		vim.b[t.buf].krs_is_multi_term = true
	end

	vim.wo[t.win].number = false
	vim.wo[t.win].relativenumber = false
	vim.wo[t.win].signcolumn = "no"

	vim.cmd("startinsert")
end

function M.toggle_selected_terminal()
	sync_terminals()
	local n = _G._krs_selected_terminal or 1
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	if active_win and current == active_win then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.api.nvim_win_close, active_win, true)
		if t.win == active_win then
			t.win = nil
		end
		for _, term in pairs(terminals) do
			if term.win == active_win then
				term.win = nil
			end
		end

		if is_valid_win(code_win) then
			pcall(vim.api.nvim_set_current_win, code_win)
		else
			vim.cmd("wincmd p")
		end
		return
	end

	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	M.open_terminal(n)
end

function M.setup()
	sync_terminals()
	for n = 1, 9 do
		local alt_key = "<A-" .. n .. ">"
		vim.keymap.set({ "n", "i", "t" }, alt_key, function()
			if vim.api.nvim_get_mode().mode == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.select_terminal(n)
		end, { noremap = true, silent = true, desc = "Select Terminal #" .. n })
	end

	local term_toggle_keys = { "<C-;>", "<A-;>" }
	for _, k in ipairs(term_toggle_keys) do
		vim.keymap.set({ "n", "i", "t" }, k, function()
			M.toggle_selected_terminal()
		end, { noremap = true, silent = true, desc = "Toggle Selected Terminal" })
	end

	vim.keymap.set("t", "<C-w>", function()
		pcall(vim.cmd, "stopinsert")
		if _G.Neotree_Smart_Quit then
			_G.Neotree_Smart_Quit()
		else
			pcall(vim.cmd, "close")
		end
	end, { noremap = true, silent = true, nowait = true, desc = "Close Terminal Window" })

	local function paste_clipboard()
		local clip = vim.fn.getreg("+")
		if not clip or clip == "" then
			clip = vim.fn.getreg("*")
		end
		if clip and clip ~= "" then
			vim.api.nvim_paste(clip, true, -1)
		end
	end

	vim.keymap.set("t", "<C-v>", paste_clipboard, { noremap = true, silent = true, desc = "Paste OS Clipboard to Terminal" })
	vim.keymap.set("t", "<C-S-v>", paste_clipboard, { noremap = true, silent = true, desc = "Paste OS Clipboard to Terminal" })
	vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, silent = true, desc = "Copy selection to OS Clipboard" })
	vim.keymap.set("v", "<C-S-c>", '"+y', { noremap = true, silent = true, desc = "Copy selection to OS Clipboard" })
end

_G.TerminalManager = M

M.setup()

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_terminal",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})
