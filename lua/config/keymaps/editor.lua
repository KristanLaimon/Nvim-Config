-- ============================================================================
-- KEYMAPS: Editor -- text, clipboard, windows, buffers.
-- ============================================================================
-- WHAT IS HERE
--   Leader, comment toggling, save, clipboard bridges, undo/redo, window
--   navigation and resizing, buffer cycling, closing things, and the file
--   explorer sidebar toggle.
--
-- WHY SO MANY ALIASES
--   `Ctrl+'` and friends arrive differently depending on keyboard layout (US,
--   US-International, ES, Latam dead keys) and terminal. The lists below bind
--   every form the same action, so the config feels identical everywhere.
-- ============================================================================

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.settings = {
	--- Space, as the prefix for every `<leader>` mapping.
	leader = " ",

	keys = {
		--- Toggle comment. One entry per keyboard layout that produces it.
		comment = { "<C-'>", "<C-S-'>", '<C-">', "<C-`>", "<C-~>", "<C-^>", "<C-acute>" },
		save = "<C-s>",
		copy = { "<C-c>", "<C-S-c>" },
		paste = { "<C-v>", "<C-S-v>" },
		undo = "<C-z>",
		redo = { "<C-y>", "<C-S-z>" },
		--- Close the current buffer/split/tab, smartly (see buffer_cleaner).
		close = "<C-w>",
		--- Move focus between windows.
		window_left = "<C-h>",
		window_right = "<C-l>",
		--- Cycle buffers.
		buffer_prev = { "<A-h>", "<M-h>", "<A-Left>", "<M-Left>" },
		buffer_next = { "<A-l>", "<M-l>", "<A-Right>", "<M-Right>" },
		--- Toggle the neo-tree sidebar.
		explorer = "<C-S-Space>",
		--- Netrw-style directory listing, kept as an escape hatch.
		netrw = "<leader>cd",
		--- Pin active code buffer tab.
		pin_tab = "<C-p>",
	},

	--- Window resize step, in cells.
	resize_step = 2,
}

-- ============================================================================
-- LEADER
-- ============================================================================

vim.g.mapleader = M.settings.leader

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Standard mapping options, with a description.
--- @param desc string
--- @return table opts
local function opts(desc)
	return { noremap = true, silent = true, desc = desc }
end

--- Feeds `keys` after leaving terminal mode, so a mapping bound in every mode
--- also works while a terminal has focus.
--- @param keys string Keys to feed (already in normal-mode form).
local function feed_from_any_mode(keys)
	return function()
		if vim.api.nvim_get_mode().mode == "t" then
			pcall(vim.cmd, "stopinsert")
			pcall(vim.cmd, "wincmd p")
		end
		vim.api.nvim_feedkeys(keys, "m", false)
	end
end

--- Pastes the OS clipboard into a terminal buffer (`"+`, falling back to `"*`).
local function paste_clipboard_to_terminal()
	local clip = vim.fn.getreg("+")
	if not clip or clip == "" then
		clip = vim.fn.getreg("*")
	end
	if clip and clip ~= "" then
		vim.api.nvim_paste(clip, true, -1)
	end
end

-- ============================================================================
-- MAPPINGS
-- ============================================================================

vim.keymap.set("n", M.settings.keys.netrw, vim.cmd.Ex, opts("Open netrw directory listing"))

-- Comments: `gcc` for a line, `gc` for a selection, from any mode.
for _, key in ipairs(M.settings.keys.comment) do
	vim.keymap.set("n", key, feed_from_any_mode("gcc"), opts("Comment line"))
	vim.keymap.set("v", key, feed_from_any_mode("gc"), opts("Comment selection"))
	vim.keymap.set("i", key, function()
		vim.cmd("stopinsert")
		feed_from_any_mode("gcc")()
	end, opts("Comment line"))
	vim.keymap.set("t", key, feed_from_any_mode("gcc"), opts("Comment line from terminal"))
end

vim.keymap.set({ "n", "v", "i" }, M.settings.keys.save, "<Cmd>w<CR>", opts("Save file"))

vim.keymap.set("n", M.settings.keys.pin_tab, function()
	require("plugins.krs.pinned_tabs").toggle_pin()
end, opts("Toggle pin tab (code buffer only)"))


-- Clipboard: the OS clipboard, not vim registers, because that is what the rest
-- of the desktop means by copy and paste.
for _, key in ipairs(M.settings.keys.copy) do
	vim.keymap.set("v", key, '"+y', opts("Copy to OS clipboard"))
end
vim.keymap.set({ "n", "v" }, "<C-v>", '"+p', opts("Paste from system clipboard"))
vim.keymap.set({ "i", "c" }, "<C-v>", "<C-r>+", opts("Paste from system clipboard"))
for _, key in ipairs(M.settings.keys.paste) do
	vim.keymap.set("t", key, paste_clipboard_to_terminal, opts("Paste OS clipboard into terminal"))
end

vim.keymap.set("n", M.settings.keys.undo, "u", opts("Undo"))
vim.keymap.set("v", M.settings.keys.undo, "<Esc>u", opts("Undo"))
vim.keymap.set("i", M.settings.keys.undo, "<C-o>u", opts("Undo"))
for _, key in ipairs(M.settings.keys.redo) do
	vim.keymap.set("n", key, "<C-r>", opts("Redo"))
	vim.keymap.set("i", key, "<C-o><C-r>", opts("Redo"))
end

-- Window focus. `<Cmd>wincmd` rather than `<C-w>h`, because <C-w> itself is
-- remapped below to "close this thing".
if M.settings.keys.window_left then
	vim.keymap.set("n", M.settings.keys.window_left, "<Cmd>wincmd h<CR>", opts("Move to left window"))
end
if M.settings.keys.window_right then
	vim.keymap.set("n", M.settings.keys.window_right, "<Cmd>wincmd l<CR>", opts("Move to right window"))
end

-- Ctrl+W closes the smallest sensible thing. The handler lives in the buffer
-- cleaner plugin; this falls back to `:bdelete` if that has not loaded yet.
vim.keymap.set({ "n", "i", "v", "t" }, M.settings.keys.close, function()
	if vim.fn.mode() == "t" then
		pcall(vim.cmd, "stopinsert")
	end
	if _G.Neotree_Smart_Quit then
		_G.Neotree_Smart_Quit()
	else
		pcall(vim.cmd, "bdelete")
	end
end, { noremap = true, silent = true, nowait = true, desc = "Close Current Tab / Buffer Immediately" })

local step = M.settings.resize_step
vim.keymap.set("n", "<C-Right>", "<Cmd>vertical resize -" .. step .. "<CR>", opts("Make window narrower"))
vim.keymap.set("n", "<C-Left>", "<Cmd>vertical resize +" .. step .. "<CR>", opts("Make window wider"))
vim.keymap.set("n", "<C-Up>", "<Cmd>resize +" .. step .. "<CR>", opts("Make window taller"))
vim.keymap.set("n", "<C-Down>", "<Cmd>resize -" .. step .. "<CR>", opts("Make window shorter"))

--- Buffer cycling is disabled inside neo-tree, where those keys navigate the tree.
--- @param command string Ex command to run.
local function safe_buf_navigate(command)
	return function()
		if vim.bo.filetype == "neo-tree" then
			return
		end
		pcall(vim.cmd, command)
	end
end

for _, key in ipairs(M.settings.keys.buffer_prev) do
	vim.keymap.set("n", key, safe_buf_navigate("BufferLineCyclePrev"), opts("Previous buffer"))
end
for _, key in ipairs(M.settings.keys.buffer_next) do
	vim.keymap.set("n", key, safe_buf_navigate("BufferLineCycleNext"), opts("Next buffer"))
end

local function toggle_neotree()
	if _G.Neotree_Toggle then
		_G.Neotree_Toggle()
	else
		if vim.api.nvim_get_mode().mode == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		vim.cmd("Neotree toggle")
		pcall(function()
			require("krs.core.dock").enforce_neotree_layout()
		end)
	end
end

vim.keymap.set({ "n", "i", "t" }, M.settings.keys.explorer, toggle_neotree, opts("Toggle Explorer"))

return M
