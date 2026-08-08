-- GLOBAL CONFIG
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

-- VSCode Migration (Old habits never die)
vim.keymap.set("n", "<C-_>", "gcc", { remap = true, desc = "Comment line" })
vim.keymap.set("v", "<C-_>", "gc", { remap = true, desc = "Comment selection" })

vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<Cmd>w<CR>", { noremap = true, silent = true, desc = "Save file" })

--
-- QOL Features
vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, desc = "Copy to clipboard" })

-- Movements across panels
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
vim.keymap.set("n", "<C-S-k>", "<C-w>k", { desc = "Move to top window" })

-- Errors / Diagnostics
vim.keymap.set("n", "<leader>k", vim.diagnostic.open_float, { desc = "Show diagnostic info" })
vim.keymap.set("n", "<leader>u", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>o", vim.diagnostic.goto_prev, { desc = "Next diagnostic" })

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file or range" })

local function Configure_Terminal_Toggle()
	-- ============================================================
	-- Toggle Terminal (multiple, indexed 1-9, <leader>t == 1)
	-- ============================================================
	local terminals = {} -- [n] = { buf = ..., win = ... }
	local code_win = nil

	local function is_valid_win(win)
		return win and vim.api.nvim_win_is_valid(win)
	end

	local function is_valid_buf(buf)
		return buf and vim.api.nvim_buf_is_valid(buf)
	end

	local function get_term(n)
		local t = terminals[n]
		if not t then
			t = { buf = nil, win = nil }
			terminals[n] = t
		end
		return t
	end

	-- Force-close a window even if it's the last one in the tab (kills the job instead of erroring)
	local function ForceCloseWin(win)
		win = win or vim.api.nvim_get_current_win()
		if #vim.api.nvim_tabpage_list_wins(0) > 1 then
			pcall(vim.api.nvim_win_close, win, true)
		else
			pcall(vim.api.nvim_buf_delete, vim.api.nvim_win_get_buf(win), { force = true })
		end
	end

	function ToggleTerminal(n)
		n = n or 1
		local t = get_term(n)

		-- Window may have been closed
		if t.win and not is_valid_win(t.win) then
			t.win = nil
		end

		local current = vim.api.nvim_get_current_win()

		------------------------------------------------------------------
		-- Currently in this terminal -> return to editor
		------------------------------------------------------------------
		if is_valid_win(t.win) and current == t.win then
			vim.cmd("stopinsert")

			if is_valid_win(code_win) then
				vim.api.nvim_set_current_win(code_win)
			else
				vim.cmd("wincmd p")
			end

			return
		end

		------------------------------------------------------------------
		-- Remember editor window
		------------------------------------------------------------------
		code_win = current

		------------------------------------------------------------------
		-- Terminal open in a different tab -> close it there instead of
		-- jumping tabs, then reopen below in the current tab
		------------------------------------------------------------------
		if is_valid_win(t.win) and vim.api.nvim_win_get_tabpage(t.win) ~= vim.api.nvim_get_current_tabpage() then
			vim.api.nvim_win_close(t.win, true)
			t.win = nil
		end

		------------------------------------------------------------------
		-- Terminal already visible
		------------------------------------------------------------------
		if is_valid_win(t.win) then
			vim.api.nvim_set_current_win(t.win)
			vim.cmd("startinsert")
			return
		end

		------------------------------------------------------------------
		-- Create terminal window
		------------------------------------------------------------------
		vim.cmd("botright 7split")
		t.win = vim.api.nvim_get_current_win()

		if is_valid_buf(t.buf) then
			vim.api.nvim_win_set_buf(t.win, t.buf)
		else
			vim.cmd("terminal")
			t.buf = vim.api.nvim_get_current_buf()
			-- Keep it out of the bufferline tab strip
			vim.bo[t.buf].buflisted = false

			vim.keymap.set("n", "<C-w>c", function()
				ForceCloseWin(t.win)
			end, { buffer = t.buf, noremap = true, silent = true, desc = "Close terminal" })
		end

		vim.cmd("startinsert")

		-- Auto-hide: leaving the terminal window hides it
		local group = vim.api.nvim_create_augroup("AutoHideTerminal" .. n, { clear = true })
		vim.api.nvim_create_autocmd("WinLeave", {
			group = group,
			buffer = t.buf,
			callback = function()
				vim.schedule(function()
					HideTerminal(n)
				end)
			end,
		})
	end

	function HideTerminal(n)
		local t = get_term(n or 1)
		if is_valid_win(t.win) then
			vim.api.nvim_win_close(t.win, true)
			t.win = nil
		end
	end

	-- Hide whichever terminal the cursor is currently inside
	local function HideCurrentTerminal()
		local current = vim.api.nvim_get_current_win()
		for n, t in pairs(terminals) do
			if t.win == current then
				ToggleTerminal(n)
				return
			end
		end
	end

	-- ============================================================
	-- Keymaps
	-- ============================================================

	for n = 1, 9 do
		local lhs = n == 1 and "<leader>t" or ("<leader>t" .. n)

		vim.keymap.set("n", lhs, function()
			ToggleTerminal(n)
		end, { noremap = true, silent = true, desc = "Toggle Terminal " .. n })
	end

	vim.keymap.set("t", "<leader>t", function()
		vim.cmd("stopinsert")
		HideCurrentTerminal()
	end, {
		noremap = true,
		silent = true,
		desc = "Toggle Terminal",
	})

	vim.keymap.set("n", "<C-;>", function()
		ToggleTerminal(1)
	end, {
		noremap = true,
		silent = true,
		desc = "Toggle Terminal",
	})

	vim.keymap.set("t", "<C-;>", function()
		vim.cmd("stopinsert")
		HideCurrentTerminal()
	end, {
		noremap = true,
		silent = true,
		desc = "Toggle Terminal",
	})

	-- Make Ctrl+W work naturally inside terminal mode
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], {
		noremap = true,
		silent = true,
	})

	-- Open Workspaces UI with Ctrl+Shift+W
	vim.keymap.set({ "n", "t" }, "<C-S-w>", function()
		if vim.fn.mode() == "t" then
			vim.cmd("stopinsert")
		end
		vim.cmd("WorkspaceSelect")
	end, {
		noremap = true,
		silent = true,
		desc = "Workspaces UI",
	})
end
Configure_Terminal_Toggle()

-- Ctrl+W closes current buffer (VSCode style tab close).
-- Dashboard.lua's autocmd shows the menu instead of quitting when
-- this closes the last listed buffer.
vim.keymap.set("n", "<C-w>", function()
	if vim.bo.filetype == "neo-tree" then
		return
	end
	vim.cmd("bdelete")
end, { noremap = true, silent = true, desc = "Close current buffer" })

-- Resize window with Ctrl+arrows
vim.keymap.set(
	"n",
	"<C-Right>",
	"<Cmd>vertical resize -2<CR>",
	{ noremap = true, silent = true, desc = "Make window narrower" }
)
vim.keymap.set(
	"n",
	"<C-Left>",
	"<Cmd>vertical resize +2<CR>",
	{ noremap = true, silent = true, desc = "Make window wider" }
)
vim.keymap.set("n", "<C-Up>", "<Cmd>resize +2<CR>", { noremap = true, silent = true, desc = "Make window taller" })
vim.keymap.set("n", "<C-Down>", "<Cmd>resize -2<CR>", { noremap = true, silent = true, desc = "Make window shorter" })

-- Switch buffers with Alt+h/l or Alt+arrows (disabled in neo-tree)
local function safe_buf_navigate(cmd)
	return function()
		if vim.bo.filetype == "neo-tree" then
			return
		end
		vim.cmd(cmd)
	end
end

vim.keymap.set("n", "<A-h>", safe_buf_navigate("BufferLineCyclePrev"), { noremap = true, silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<A-l>", safe_buf_navigate("BufferLineCycleNext"), { noremap = true, silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<A-Left>", safe_buf_navigate("BufferLineCyclePrev"), { noremap = true, silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<A-Right>", safe_buf_navigate("BufferLineCycleNext"), { noremap = true, silent = true, desc = "Next buffer" })

-- Live preview of :colorscheme while navigating with Tab
local colorscheme_preview_orig = nil
vim.api.nvim_create_autocmd("CmdlineChanged", {
	callback = function()
		if vim.fn.getcmdtype() ~= ":" then
			return
		end

		local cmdline = vim.fn.getcmdline()
		local name = cmdline:match("^colo%S*%s+(%S+)%s*$")

		if not name then
			return
		end

		if colorscheme_preview_orig == nil then
			colorscheme_preview_orig = vim.g.colors_name
		end

		pcall(vim.cmd.colorscheme, name)
	end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
	callback = function()
		if vim.fn.getcmdtype() ~= ":" then
			return
		end

		local cmdline = vim.fn.getcmdline()
		local applied = cmdline:match("^colo%S*%s+(%S+)%s*$")

		-- Cancelled (Esc) without confirming -> revert to previous colorscheme
		if colorscheme_preview_orig and vim.v.event.abort and not applied then
			pcall(vim.cmd.colorscheme, colorscheme_preview_orig)
		end

		colorscheme_preview_orig = nil
	end,
})

-- View current image as pixel art (chafa) in floating window
vim.keymap.set("n", "<leader>i", function()
	local path = vim.api.nvim_buf_get_name(0)

	-- If focus is in neo-tree or non-file window, find first visible file buffer
	if path == "" or vim.fn.filereadable(path) == 0 or vim.bo.filetype == "neo-tree" then
		path = ""
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype ~= "neo-tree" and vim.bo[b].buftype == "" then
				local name = vim.api.nvim_buf_get_name(b)
				if name ~= "" and vim.fn.filereadable(name) == 1 then
					path = name
					break
				end
			end
		end
	end

	if path == "" then
		vim.notify("No file to display", vim.log.levels.WARN)
		return
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	})

	vim.fn.termopen(string.format("chafa --size=%dx%d %s", width, height, vim.fn.shellescape(path)))
	vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", { buffer = buf, silent = true })
end, { noremap = true, silent = true, desc = "View image (chafa)" })

-- =========== Plugin Specifics =================
-- Neo-tree
-- Open/Close (Sidebar)
vim.keymap.set("n", "<C-S-Space>", ":Neotree toggle<CR>", { noremap = true, silent = true, desc = "Toggle Explorer" })

-- F2: rename. Inside neo-tree uses its rename; in normal buffer renames file on disk.
vim.keymap.set("n", "<F2>", function()
	if vim.bo.filetype == "neo-tree" then
		vim.api.nvim_feedkeys("r", "m", false)
		return
	end

	local old_path = vim.api.nvim_buf_get_name(0)
	if old_path == "" then
		vim.notify("Buffer has no file, cannot rename", vim.log.levels.WARN)
		return
	end

	local dir = vim.fn.fnamemodify(old_path, ":h")
	local old_name = vim.fn.fnamemodify(old_path, ":t")

	vim.ui.input({ prompt = "Rename to: ", default = old_name }, function(new_name)
		if not new_name or new_name == "" or new_name == old_name then
			return
		end

		local new_path = dir .. "/" .. new_name

		if vim.fn.filereadable(new_path) == 1 then
			vim.notify("File already exists: " .. new_path, vim.log.levels.ERROR)
			return
		end

		vim.cmd("write")
		local ok, err = os.rename(old_path, new_path)
		if not ok then
			vim.notify("Error renaming file: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		vim.cmd("edit " .. vim.fn.fnameescape(new_path))
		vim.cmd("bdelete " .. vim.fn.fnameescape(old_path))
	end)
end, { noremap = true, silent = true, desc = "Rename file" })
