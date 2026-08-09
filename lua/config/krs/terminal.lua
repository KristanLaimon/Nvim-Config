-- ============================================================================
-- 🦊 KRS CONFIG: Lazy Loading Multi-Terminal Manager
-- ============================================================================
-- 1. Manages 9 independent terminals (1-9) with Lazy Loading.
-- 2. <Alt + 1> .. <Alt + 9> selects and switches to terminal #n.
-- 3. <Ctrl + ;> toggles open/hidden for currently SELECTED terminal.
-- 4. Supports clean navigation between code editor and terminals.
-- ============================================================================

local M = {}

local terminals = {} -- Structure: [n] = { buf = number|nil, win = number|nil }
local selected_terminal = 1 -- Currently selected terminal index (1 by default)
local code_win = nil -- Origin code window to return with clean focus

-- Build the `:terminal` command, dropping into WSL when cwd lives inside a
-- WSL distro's filesystem (`\\wsl.localhost\<Distro>\...`) instead of the
-- default Windows shell.
local function terminal_open_cmd()
	local ok, wsl = pcall(require, "config.krs.wsl")
	local wsl_cmd = ok and wsl.shell_command_for_cwd(vim.fn.getcwd()) or nil
	return wsl_cmd and ("terminal " .. wsl_cmd) or "terminal"
end

-- Check if window is valid
local function is_valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

-- Check if buffer is valid
local function is_valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

-- Get or initialize reference for terminal n (Lazy Loading)
local function get_term(n)
	local t = terminals[n]
	if not t then
		t = { buf = nil, win = nil }
		terminals[n] = t
	end
	return t
end

-- Get currently visible terminal window (if any)
local function get_active_terminal_win()
	for _, t in pairs(terminals) do
		if is_valid_win(t.win) then
			return t.win
		end
	end
	return nil
end

-- Get currently selected terminal (1-9)
function M.get_selected_terminal()
	return selected_terminal
end

-- Select terminal #n (Alt + 1..9)
function M.select_terminal(n)
	selected_terminal = n
	local t = get_term(n)
	local current_win = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- If not in terminal window, save current code window
	if not active_win or current_win ~= active_win then
		code_win = current_win
	end

	if is_valid_win(active_win) then
		-- If split terminal window already visible below: change buffer
		t.win = active_win
		if is_valid_buf(t.buf) then
			vim.api.nvim_win_set_buf(t.win, t.buf)
		else
			-- Lazy load terminal #n for the first time
			vim.api.nvim_set_current_win(t.win)
			vim.cmd(terminal_open_cmd())
			t.buf = vim.api.nvim_get_current_buf()
			vim.bo[t.buf].buflisted = false
		end
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
	else
		-- If no terminal window open, open selected terminal
		M.open_terminal(n)
	end

	vim.notify("🖥️ Terminal #" .. n .. " active", vim.log.levels.INFO, { title = "Multi-Terminal" })
end

-- Open/Show a specific terminal
function M.open_terminal(n)
	n = n or selected_terminal
	selected_terminal = n
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- Save code window
	if current ~= active_win then
		code_win = current
	end

	-- If window is no longer valid, clear reference
	if t.win and not is_valid_win(t.win) then
		t.win = nil
	end

	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	-- Create bottom split window (10 lines)
	vim.cmd("botright 10split")
	t.win = vim.api.nvim_get_current_win()

	if is_valid_buf(t.buf) then
		vim.api.nvim_win_set_buf(t.win, t.buf)
	else
		-- Lazy load terminal process #n
		vim.cmd(terminal_open_cmd())
		t.buf = vim.api.nvim_get_current_buf()
		vim.bo[t.buf].buflisted = false
	end

	-- Terminal window visual settings
	vim.wo[t.win].number = false
	vim.wo[t.win].relativenumber = false
	vim.wo[t.win].signcolumn = "no"

	vim.cmd("startinsert")
end

-- Toggle selected terminal with Ctrl + ;
function M.toggle_selected_terminal()
	local n = selected_terminal
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- Case 1: Cursor is in terminal window -> Hide it and return to code
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

	-- Case 2: Terminal is open but unfocused -> Focus it
	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	-- Case 3: Open selected terminal
	M.open_terminal(n)
end

-- Global Keymaps configuration
function M.setup()
	-- Alt + 1..9 to select/manage Terminal 1..9 in Normal, Insert, and Terminal modes
	for n = 1, 9 do
		local alt_key = "<A-" .. n .. ">"
		vim.keymap.set({ "n", "i", "t" }, alt_key, function()
			if vim.api.nvim_get_mode().mode == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.select_terminal(n)
		end, { noremap = true, silent = true, desc = "Select Terminal #" .. n })
	end

	-- Ctrl + ; to toggle open/hidden for currently selected terminal
	vim.keymap.set({ "n", "i", "t" }, "<C-;>", function()
		M.toggle_selected_terminal()
	end, { noremap = true, silent = true, desc = "Toggle Selected Terminal" })

	-- Allow standard navigation with Ctrl+W from inside terminal
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { noremap = true, silent = true })
end

return M

