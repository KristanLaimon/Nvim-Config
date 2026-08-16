-- ============================================================================
-- KRS PLUGIN: Multi-Terminal -- nine lazily created terminals in one dock slot.
-- ============================================================================
-- WHAT IT DOES
--   1. Manages `M.settings.count` independent terminals, created on first use.
--   2. <A-1>..<A-9> selects a terminal and shows it in the dock's terminal pane.
--   3. <C-;> / <A-;> toggles the SELECTED terminal open and hidden.
--   4. Remembers the code window you came from, so closing returns focus there.
--   5. Survives a config reload: the terminal table lives on `_G`, and
--      `sync_terminals` re-adopts terminal buffers that lost their slot.
--
-- WHY BUFFER VARIABLES
--   `krs_term_num` (slot) and `krs_is_multi_term` (ownership) live on the buffer
--   itself, so a reload, a session restore or a stray `:terminal` can be mapped
--   back to a slot without keeping a parallel registry in sync.
--
-- COLLABORATORS
--   krs.core.dock      Bottom dock shared with the task runner.
--   plugins.krs.wsl    Chooses the WSL shell when the project lives under WSL.
-- ============================================================================

local dock = require("krs.core.dock")
local store = require("krs.core.store")

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.settings = {
	--- How many terminals exist. `<A-n>` is bound for each.
	count = 9,

	--- Height of a freshly opened terminal split, when nothing is saved yet.
	default_height = 10,

	--- Accepted range for the remembered height; anything else is ignored.
	min_height = 3,
	max_height = 100,

	--- Where the last used terminal height is remembered.
	height_file = vim.fn.stdpath("state") .. "/terminal_height",

	keys = {
		--- Prefix for per-terminal selection; the number is appended (`<A-1>`).
		select_prefix = "<A-",
		--- Toggle the selected terminal.
		toggle = { "<C-;>", "<A-;>" },
		--- Close the terminal window from inside terminal mode.
		close = "<C-w>",
		--- Clipboard bridges, because a terminal has no access to registers.
		paste = { "<C-v>", "<C-S-v>" },
		copy = { "<C-c>", "<C-S-c>" },
	},
}

-- ============================================================================
-- STATE -- kept on _G so a config reload does not orphan open terminals
-- ============================================================================

_G._krs_terminals = _G._krs_terminals or {}
_G._krs_selected_terminal = _G._krs_selected_terminal or 1

--- `[n] = { buf = integer|nil, win = integer|nil }`
local terminals = _G._krs_terminals

--- Window to return to when the terminal is dismissed.
local code_win = nil

--- Current terminal split height, persisted across sessions.
local terminal_height

-- ============================================================================
-- HEIGHT PERSISTENCE
-- ============================================================================

--- Reads the remembered height, falling back to the default.
--- @return integer height
local function load_saved_height()
	local raw = store.read_file(M.settings.height_file)
	local height = raw and tonumber(raw) or nil
	if height and height >= M.settings.min_height and height <= M.settings.max_height then
		return height
	end
	return M.settings.default_height
end

terminal_height = load_saved_height()

--- Remembers a new height when it is in range and actually changed.
--- @param height integer
local function save_height(height)
	if type(height) ~= "number" or height < M.settings.min_height or height > M.settings.max_height then
		return
	end
	if height == terminal_height then
		return
	end
	terminal_height = height
	store.write_file(M.settings.height_file, tostring(height))
end

-- ============================================================================
-- SLOT BOOKKEEPING
-- ============================================================================

--- @param win integer|nil
--- @return boolean
local function is_valid_win(win)
	return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

--- @param buf integer|nil
--- @return boolean
local function is_valid_buf(buf)
	return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

--- Slot record for terminal `n`, created on demand.
--- @param n integer
--- @return table slot `{ buf, win }`
local function get_term(n)
	terminals[n] = terminals[n] or { buf = nil, win = nil }
	return terminals[n]
end

--- Claims `bufnr` for the first free slot, tagging the buffer with its number.
--- @param bufnr integer
--- @param winid integer|nil Window showing the buffer, when it has one.
--- @return integer|nil slot
local function adopt_buffer(bufnr, winid)
	for n = 1, M.settings.count do
		local t = get_term(n)
		if not is_valid_buf(t.buf) then
			t.buf = bufnr
			t.win = winid or t.win
			vim.b[bufnr].krs_term_num = n
			vim.b[bufnr].krs_is_multi_term = true
			return n
		end
	end
	return nil
end

--- True for a terminal buffer this plugin may own (task outputs are excluded).
--- @param bufnr integer
--- @return boolean
local function is_adoptable(bufnr)
	return vim.bo[bufnr].buftype == "terminal" and not vim.b[bufnr].krs_is_task
end

--- Reconciles the slot table with reality: drops dead handles, re-attaches
--- tagged buffers, and adopts untagged terminals (from a session or `:terminal`).
local function sync_terminals()
	for n = 1, M.settings.count do
		local t = terminals[n]
		if t then
			t.win = is_valid_win(t.win) and t.win or nil
			t.buf = is_valid_buf(t.buf) and t.buf or nil
		end
	end

	-- Visible terminals first, so a slot keeps the window it is displayed in.
	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(winid) then
			local bufnr = vim.api.nvim_win_get_buf(winid)
			if vim.api.nvim_buf_is_valid(bufnr) then
				local term_num = vim.b[bufnr].krs_term_num
				if term_num and term_num >= 1 and term_num <= M.settings.count then
					local t = get_term(term_num)
					t.buf, t.win = bufnr, winid
				elseif is_adoptable(bufnr) then
					adopt_buffer(bufnr, winid)
				end
			end
		end
	end

	-- Then hidden terminal buffers, which have no window to record.
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local term_num = vim.b[bufnr].krs_term_num
			if term_num and term_num >= 1 and term_num <= M.settings.count then
				local t = get_term(term_num)
				if not is_valid_buf(t.buf) then
					t.buf = bufnr
				end
			elseif is_adoptable(bufnr) then
				adopt_buffer(bufnr, nil)
			end
		end
	end
end

--- The window currently hosting a terminal: the selected one when it is visible,
--- otherwise any visible terminal.
--- @return integer|nil win
local function get_active_terminal_win()
	sync_terminals()

	local selected = terminals[_G._krs_selected_terminal or 1]
	if selected and is_valid_win(selected.win) then
		return selected.win
	end
	for _, t in pairs(terminals) do
		if is_valid_win(t.win) then
			return t.win
		end
	end
	return nil
end

-- ============================================================================
-- TERMINAL CREATION
-- ============================================================================

--- `:terminal` command for the current project, routed through WSL when the
--- project lives on a WSL path.
--- @return string cmd
local function terminal_open_cmd()
	local ok, wsl = pcall(require, "plugins.krs.wsl")
	local wsl_cmd = ok and wsl.shell_command_for_cwd(vim.fn.getcwd()) or nil
	return wsl_cmd and ("terminal " .. wsl_cmd) or "terminal"
end

--- Shows terminal `n` in `win`, spawning the shell when the slot has no buffer.
--- @param t table Slot record.
--- @param n integer Slot number.
--- @param win integer Window to fill.
local function fill_window(t, n, win)
	if is_valid_buf(t.buf) then
		vim.api.nvim_win_set_buf(win, t.buf)
		return
	end

	vim.api.nvim_set_current_win(win)
	vim.cmd(terminal_open_cmd())
	t.buf = vim.api.nvim_get_current_buf()
	vim.bo[t.buf].buflisted = false
	vim.b[t.buf].krs_term_num = n
	vim.b[t.buf].krs_is_multi_term = true
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Currently selected terminal number.
--- @return integer n
function M.get_selected_terminal()
	return _G._krs_selected_terminal or 1
end

--- Selects terminal `n` and shows it, reusing the visible terminal window.
--- @param n integer Slot number.
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
		fill_window(t, n, t.win)
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
	else
		M.open_terminal(n)
	end

	vim.notify("🖥️ Terminal #" .. n .. " active", vim.log.levels.INFO, { title = "Multi-Terminal" })
end

--- Opens terminal `n`, creating the dock pane when there is none.
--- @param n integer|nil Slot number. Defaults to the selected terminal.
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

	-- Already on screen: just focus it.
	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	-- Another terminal is on screen: take over its pane.
	if is_valid_win(active_win) then
		t.win = active_win
		fill_window(t, n, t.win)
		vim.cmd("startinsert")
		return
	end

	t.win = dock.open({ prefer = "terminal", height = terminal_height })
	fill_window(t, n, t.win)
	dock.style(t.win)
	vim.cmd("startinsert")
end

--- Hides the terminal when focused, shows or creates it otherwise.
function M.toggle_selected_terminal()
	sync_terminals()

	local n = _G._krs_selected_terminal or 1
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	if active_win and current == active_win then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.api.nvim_win_close, active_win, true)

		-- Every slot sharing that pane loses its window handle, not just this one.
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

--- Re-exported for callers that relied on this module owning the dock order.
M.enforce_bottom_layout = dock.enforce_order

-- ============================================================================
-- SETUP
-- ============================================================================

--- Pastes the OS clipboard into a terminal (`"+`, falling back to `"*`).
local function paste_clipboard()
	local clip = vim.fn.getreg("+")
	if not clip or clip == "" then
		clip = vim.fn.getreg("*")
	end
	if clip and clip ~= "" then
		vim.api.nvim_paste(clip, true, -1)
	end
end

--- Binds selection, toggling, closing and clipboard keys, and starts the
--- autocmd that remembers a resized terminal's height.
function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	sync_terminals()

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

	for n = 1, M.settings.count do
		vim.keymap.set({ "n", "i", "t" }, M.settings.keys.select_prefix .. n .. ">", function()
			if vim.api.nvim_get_mode().mode == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.select_terminal(n)
		end, { noremap = true, silent = true, desc = "Select Terminal #" .. n })
	end

	for _, key in ipairs(M.settings.keys.toggle) do
		vim.keymap.set({ "n", "i", "t" }, key, M.toggle_selected_terminal, {
			noremap = true,
			silent = true,
			desc = "Toggle Selected Terminal",
		})
	end

	vim.keymap.set("t", M.settings.keys.close, function()
		pcall(vim.cmd, "stopinsert")
		-- Neo-tree installs a smarter close that also handles its own window.
		if _G.Neotree_Smart_Quit then
			_G.Neotree_Smart_Quit()
		else
			pcall(vim.cmd, "close")
		end
	end, { noremap = true, silent = true, nowait = true, desc = "Close Terminal Window" })

	for _, key in ipairs(M.settings.keys.paste) do
		vim.keymap.set("t", key, paste_clipboard, {
			noremap = true,
			silent = true,
			desc = "Paste OS Clipboard to Terminal",
		})
	end
	for _, key in ipairs(M.settings.keys.copy) do
		vim.keymap.set("v", key, '"+y', {
			noremap = true,
			silent = true,
			desc = "Copy selection to OS Clipboard",
		})
	end
end

-- Legacy global kept for user scripts and older keybinds that reference it.
_G.TerminalManager = M

-- ============================================================================
-- LAZY.NVIM SPEC
-- ============================================================================

return setmetatable({
	name = "krs_terminal",
	dir = require("krs.core.lazyspec").for_module(),
	cmd = { "TerminalToggle", "TerminalSelect" },
	keys = {
		{ "<C-;>", mode = { "n", "i", "t" }, desc = "Toggle Selected Terminal" },
	},
	config = M.setup,
}, { __index = M })
