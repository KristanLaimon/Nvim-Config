-- GLOBAL CONFIG
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

-- Comment keymapping (Ctrl + ' for US Standard, US International, ES & Latam dead-key layouts)
local comment_keys = { "<C-'>", "<C-S-'>", '<C-">', "<C-`>", "<C-~>", "<C-^>", "<C-acute>" }

local function comment_line()
	local mode = vim.api.nvim_get_mode().mode
	if mode == "t" then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.cmd, "wincmd p")
	end
	vim.api.nvim_feedkeys("gcc", "m", false)
end

local function comment_selection()
	local mode = vim.api.nvim_get_mode().mode
	if mode == "t" then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.cmd, "wincmd p")
	end
	vim.api.nvim_feedkeys("gc", "m", false)
end

for _, key in ipairs(comment_keys) do
	vim.keymap.set("n", key, comment_line, { noremap = true, silent = true, desc = "Comment line" })
	vim.keymap.set("v", key, comment_selection, { noremap = true, silent = true, desc = "Comment selection" })
	vim.keymap.set("i", key, function()
		vim.cmd("stopinsert")
		comment_line()
	end, { noremap = true, silent = true, desc = "Comment line" })
	vim.keymap.set("t", key, comment_line, { noremap = true, silent = true, desc = "Comment line from terminal" })
end

-- Global Search Keymaps: Ctrl+/ (respect .gitignore) vs Ctrl+Shift+/ (search all files)
local gitignore_search_keys = { "<C-/>" }
for _, key in ipairs(gitignore_search_keys) do
	vim.keymap.set({ "n", "i" }, key, function()
		if _G.FindFilesGitignore then
			_G.FindFilesGitignore()
		else
			require("telescope.builtin").find_files({ no_ignore = false })
		end
	end, { noremap = true, silent = true, desc = "Find files (respecting .gitignore)" })
end

local all_files_search_keys = { "<C-S-/>", "<C-?>" }
for _, key in ipairs(all_files_search_keys) do
	vim.keymap.set({ "n", "i" }, key, function()
		if _G.FindFilesNoIgnore then
			_G.FindFilesNoIgnore()
		else
			require("telescope.builtin").find_files({ no_ignore = true, hidden = true })
		end
	end, { noremap = true, silent = true, desc = "Find all files (ignoring .gitignore)" })
end

vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<Cmd>w<CR>", { noremap = true, silent = true, desc = "Save file" })

-- QOL Features & Clipboard (Ctrl+C = Copy, Ctrl+V = Paste from system)
local function paste_clipboard_to_terminal()
	local clip = vim.fn.getreg("+")
	if not clip or clip == "" then
		clip = vim.fn.getreg("*")
	end
	if clip and clip ~= "" then
		vim.api.nvim_paste(clip, true, -1)
	end
end

vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, silent = true, desc = "Copy to OS clipboard" })
vim.keymap.set("v", "<C-S-c>", '"+y', { noremap = true, silent = true, desc = "Copy to OS clipboard" })
vim.keymap.set({ "n", "v" }, "<C-v>", '"+p', { noremap = true, silent = true, desc = "Paste from system clipboard" })
vim.keymap.set({ "i", "c" }, "<C-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from system clipboard" })
vim.keymap.set(
	"t",
	"<C-v>",
	paste_clipboard_to_terminal,
	{ noremap = true, silent = true, desc = "Paste OS clipboard into terminal" }
)
vim.keymap.set(
	"t",
	"<C-S-v>",
	paste_clipboard_to_terminal,
	{ noremap = true, silent = true, desc = "Paste OS clipboard into terminal" }
)
-- Undo / Redo (Ctrl+Z = Undo, Ctrl+Y / Ctrl+Shift+Z = Redo)
vim.keymap.set("n", "<C-z>", "u", { noremap = true, silent = true, desc = "Undo" })
vim.keymap.set("v", "<C-z>", "<Esc>u", { noremap = true, silent = true, desc = "Undo" })
vim.keymap.set("i", "<C-z>", "<C-o>u", { noremap = true, silent = true, desc = "Undo" })

vim.keymap.set("n", "<C-y>", "<C-r>", { noremap = true, silent = true, desc = "Redo" })
vim.keymap.set("n", "<C-S-z>", "<C-r>", { noremap = true, silent = true, desc = "Redo" })
vim.keymap.set("i", "<C-y>", "<C-o><C-r>", { noremap = true, silent = true, desc = "Redo" })
vim.keymap.set("i", "<C-S-z>", "<C-o><C-r>", { noremap = true, silent = true, desc = "Redo" })

-- Movements across panels & split windows
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Open file picker in directional splits with Ctrl + Shift + H/J/K/L
local function open_find_files_split(direction)
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("Telescope is not ready", vim.log.levels.ERROR)
		return
	end
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local dir_names = {
		h = "Left (←)",
		j = "Down (↓)",
		k = "Up (↑)",
		l = "Right (→)",
	}

	builtin.find_files({
		prompt_title = " 🔍 Open File to the " .. (dir_names[direction] or direction) .. " ",
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and (selection.value or selection[1]) then
					local filepath = selection.value or selection[1]
					local cmd
					if direction == "h" then
						cmd = "leftabove vsplit"
					elseif direction == "l" then
						cmd = "rightbelow vsplit"
					elseif direction == "k" then
						cmd = "leftabove split"
					elseif direction == "j" then
						cmd = "rightbelow split"
					end
					if cmd then
						vim.cmd(cmd .. " " .. vim.fn.fnameescape(filepath))
					end
				end
			end)
			return true
		end,
	})
end

local split_modes = { "n", "i", "v" }
local split_binds = {
	h = { "<C-S-h>", "<C-S-H>" },
	j = { "<C-S-j>", "<C-S-J>" },
	k = { "<C-S-k>", "<C-S-K>" },
	l = { "<C-S-l>", "<C-S-L>" },
}

-- While a debug session is running, <C-S-j> toggles the repl ("immediate window")
-- instead of opening a file split: hidden -> open and focus, visible -> focus,
-- already focused -> close the whole bottom layout.
local function dap_toggle_repl()
	local dap_ok, dap = pcall(require, "dap")
	if not dap_ok or not dap.session() then
		return false
	end
	local dapui_ok, dapui = pcall(require, "dapui")
	if not dapui_ok then
		return false
	end
	local repl_win
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-repl" then
			repl_win = win
			break
		end
	end
	if repl_win == vim.api.nvim_get_current_win() then
		-- layout 2 is the bottom { repl, console } panel from dapui.setup()
		pcall(dapui.close, { layout = 2 })
	elseif repl_win then
		vim.api.nvim_set_current_win(repl_win)
	else
		pcall(dapui.open, { layout = 2 })
		vim.schedule(function()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-repl" then
					vim.api.nvim_set_current_win(win)
					return
				end
			end
		end)
	end
	return true
end

for dir, keys in pairs(split_binds) do
	for _, key in ipairs(keys) do
		vim.keymap.set(split_modes, key, function()
			if dir == "j" and dap_toggle_repl() then
				return
			end
			open_find_files_split(dir)
		end, { noremap = true, silent = true, desc = "Find file and open in split (" .. dir .. ")" })
	end
end

-- Signature / Parameter Intellisense Help with Ctrl+j
local function trigger_signature_help()
	local get_cls = vim.lsp.get_clients or vim.lsp.get_active_clients
	local clients = get_cls({ bufnr = 0 })
	if clients and #clients > 0 then
		pcall(vim.lsp.buf.signature_help, { border = "rounded", focusable = false })
		pcall(vim.lsp.buf.hover, { border = "rounded" })
	else
		vim.notify("No active LSP for parameter help", vim.log.levels.WARN, { title = "LSP Signature Help" })
	end
end

vim.keymap.set(
	{ "n", "i", "v" },
	"<C-j>",
	trigger_signature_help,
	{ noremap = true, silent = true, desc = "Show parameter signature help" }
)

-- Graceful Hover Documentation (K) without E149 errors
vim.keymap.set("n", "K", function()
	pcall(function()
		vim.lsp.buf.hover({ border = "rounded" })
	end)
end, { noremap = true, silent = true, desc = "Show hover documentation" })

-- Errors / Diagnostics
local function show_diagnostic_float()
	vim.diagnostic.open_float({ border = "rounded", scope = "cursor", focusable = true })
end

vim.keymap.set("n", "<leader>k", show_diagnostic_float, { desc = "Show diagnostic info" })
vim.keymap.set("n", "<leader>u", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>o", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- VSCode Quick Fix / Suggestions with Ctrl + . (Mini Dropdown at Caret position)
local function cursor_ui_select(items, opts, on_choice)
	opts = opts or {}
	local prompt = opts.prompt or "Available Code Actions:"
	prompt = prompt:gsub("^%s*", ""):gsub("%s*$", "")

	-- Sort so preferred / quickfix actions surface first instead of raw LSP order
	local kind_priority = {
		quickfix = 1,
		["refactor.rewrite"] = 2,
		refactor = 3,
		["source.fixAll"] = 4,
		["source.organizeImports"] = 5,
		source = 6,
	}
	local order = {}
	for i in ipairs(items) do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local ia, ib = items[a], items[b]
		local action_a = ia.action or ia
		local action_b = ib.action or ib
		local pref_a = action_a.isPreferred and 0 or 1
		local pref_b = action_b.isPreferred and 0 or 1
		if pref_a ~= pref_b then
			return pref_a < pref_b
		end
		local kind_a = kind_priority[action_a.kind] or 99
		local kind_b = kind_priority[action_b.kind] or 99
		if kind_a ~= kind_b then
			return kind_a < kind_b
		end
		return a < b
	end)
	local sorted_items = {}
	for i, idx in ipairs(order) do
		sorted_items[i] = items[idx]
	end
	items = sorted_items

	local formatted_items = {}
	for i, item in ipairs(items) do
		local text = opts.format_item and opts.format_item(item) or tostring(item)
		table.insert(formatted_items, string.format("%d. %s", i, text))
	end

	if #formatted_items == 0 then
		vim.notify("No code suggestions available here", vim.log.levels.INFO, { title = "LSP Code Actions" })
		return
	end

	local max_width = #prompt + 6
	for _, str in ipairs(formatted_items) do
		if #str > max_width then
			max_width = #str
		end
	end
	max_width = math.min(math.max(max_width + 4, 40), 85)

	local buf = vim.api.nvim_create_buf(false, true)
	local lines = { " 💡 " .. prompt, string.rep("─", max_width - 2) }
	for _, item_str in ipairs(formatted_items) do
		table.insert(lines, "  " .. item_str)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Create floating window anchored to CURSOR (caret position)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = max_width,
		height = #lines,
		style = "minimal",
		border = "rounded",
	})

	pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = win })

	local selected_idx = 1
	local function set_cursor_pos(idx)
		selected_idx = math.max(1, math.min(#formatted_items, idx))
		pcall(vim.api.nvim_win_set_cursor, win, { selected_idx + 2, 2 })
	end
	set_cursor_pos(1)

	local function close_win()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local function confirm_choice()
		local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win)
		if ok then
			local idx = cursor[1] - 2
			if idx >= 1 and idx <= #items then
				selected_idx = idx
			end
		end
		close_win()
		if on_choice and items[selected_idx] then
			on_choice(items[selected_idx], selected_idx)
		end
	end

	local keymap_opts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set("n", "<CR>", confirm_choice, keymap_opts)
	vim.keymap.set("n", "j", function()
		set_cursor_pos(selected_idx + 1)
	end, keymap_opts)
	vim.keymap.set("n", "k", function()
		set_cursor_pos(selected_idx - 1)
	end, keymap_opts)
	vim.keymap.set("n", "<Down>", function()
		set_cursor_pos(selected_idx + 1)
	end, keymap_opts)
	vim.keymap.set("n", "<Up>", function()
		set_cursor_pos(selected_idx - 1)
	end, keymap_opts)
	vim.keymap.set("n", "<Esc>", function()
		close_win()
		if on_choice then
			on_choice(nil, nil)
		end
	end, keymap_opts)
	vim.keymap.set("n", "q", function()
		close_win()
		if on_choice then
			on_choice(nil, nil)
		end
	end, keymap_opts)

	for i = 1, math.min(9, #formatted_items) do
		vim.keymap.set("n", tostring(i), function()
			selected_idx = i
			confirm_choice()
		end, keymap_opts)
	end
end

local function vscode_quick_fix()
	local get_cls = vim.lsp.get_clients or vim.lsp.get_active_clients
	local clients = get_cls({ bufnr = 0 })
	if not clients or #clients == 0 then
		vim.notify("No active LSP server for this file", vim.log.levels.WARN, { title = "LSP Code Actions" })
		return
	end

	local orig_select = vim.ui.select
	vim.ui.select = function(items, opts, on_choice)
		vim.ui.select = orig_select
		if not items or #items == 0 then
			vim.notify("No suggestions or code actions available here", vim.log.levels.INFO, { title = "LSP Code Actions" })
			return
		end
		cursor_ui_select(items, opts, on_choice)
	end

	pcall(vim.lsp.buf.code_action)
end

vim.keymap.set(
	{ "n", "i", "v" },
	"<C-.>",
	vscode_quick_fix,
	{ noremap = true, silent = true, desc = "Quick Fix / Code Actions (Dropdown at Caret)" }
)

-- Go to Definition with Alt+j (and jump back with Ctrl+o)
-- Shows Telescope definitions list if multiple matches exist with live preview (navigable with j/k)
local function goto_definition()
	vim.cmd("normal! m'")
	local get_cls = vim.lsp.get_clients or vim.lsp.get_active_clients
	local clients = get_cls({ bufnr = 0 })
	if clients and #clients > 0 then
		local has_telescope, builtin = pcall(require, "telescope.builtin")
		if has_telescope then
			builtin.lsp_definitions({
				jump_type = "never",
				reuse_win = true,
				show_line = true,
			})
		else
			vim.lsp.buf.definition()
		end
	else
		local ok = pcall(function()
			vim.cmd("normal! \x1d")
		end)
		if not ok then
			vim.notify("No definition found", vim.log.levels.WARN, { title = "LSP" })
		end
	end
end

vim.keymap.set(
	{ "n", "i", "v" },
	"<A-k>",
	goto_definition,
	{ noremap = true, silent = true, desc = "Go to definition" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<M-k>",
	goto_definition,
	{ noremap = true, silent = true, desc = "Go to definition" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<A-j>",
	goto_definition,
	{ noremap = true, silent = true, desc = "Go to definition" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<M-j>",
	goto_definition,
	{ noremap = true, silent = true, desc = "Go to definition" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<C-S-d>",
	goto_definition,
	{ noremap = true, silent = true, desc = "Go to definition" }
)

-- Debugging (DAP) Keybindings
local function dap_toggle_breakpoint()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.toggle_breakpoint()
		vim.defer_fn(function()
			pcall(function()
				require("plugins.krs.dap_breakpoints").save_breakpoints()
			end)
		end, 100)
	end
end
local function dap_continue()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.continue()
	end
end
local function dap_step_over()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.step_over()
	end
end
local function dap_step_into()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.step_into()
	end
end
local function dap_step_out()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.step_out()
	end
end
local function dap_terminate()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.terminate()
		pcall(function()
			require("dapui").close()
		end)
	end
end
local function dap_toggle_ui()
	local ok, dapui = pcall(require, "dapui")
	if ok then
		dapui.toggle()
	end
end

vim.keymap.set(
	{ "n", "i", "v" },
	"<C-b>",
	dap_toggle_breakpoint,
	{ noremap = true, silent = true, desc = "Toggle Breakpoint" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<F5>",
	dap_continue,
	{ noremap = true, silent = true, desc = "Start/Continue Debugging" }
)
vim.keymap.set({ "n", "i", "v" }, "<F10>", dap_step_over, { noremap = true, silent = true, desc = "Step Over" })
vim.keymap.set({ "n", "i", "v" }, "<F11>", dap_step_into, { noremap = true, silent = true, desc = "Step Into" })
vim.keymap.set({ "n", "i", "v" }, "<F12>", dap_step_out, { noremap = true, silent = true, desc = "Step Out" })
vim.keymap.set(
	{ "n", "i", "v" },
	"<S-F5>",
	dap_terminate,
	{ noremap = true, silent = true, desc = "Terminate Debugger" }
)
vim.keymap.set("n", "<leader>du", dap_toggle_ui, { noremap = true, silent = true, desc = "Toggle Debugger UI" })

-- Git Stage All Unstaged & Untracked Changes (Ctrl + Shift + X / Ctrl + Alt + S / Alt + S) with Modal Window Confirmation
-- Works everywhere (Normal, Insert, Visual, Terminal)
local function stage_all_with_modal_handler()
	if vim.fn.mode() == "t" then
		pcall(vim.cmd, "stopinsert")
	end
	require("plugins.krs.git_center").stage_all_with_modal()
end

local stage_all_keys = {
	"<C-S-x>", "<C-S-X>",
	"<C-A-s>", "<C-A-S>", "<C-M-s>", "<C-M-S>",
	"<A-C-s>", "<A-C-S>", "<M-C-s>", "<M-C-S>",
	"<A-s>", "<A-S>", "<M-s>", "<M-S>",
}

for _, lhs in ipairs(stage_all_keys) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, stage_all_with_modal_handler, {
		noremap = true,
		silent = true,
		desc = "Stage all unstaged changes in git (Modal Confirmation)",
	})
end




for _, lhs in ipairs({ "<C-S-s>", "<C-S-S>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		require("plugins.krs.launch_profiles").handle_smart_launch()
	end, { noremap = true, silent = true, desc = "Smart Launch / Profile Debug UI" })
end

for _, lhs in ipairs({ "<C-S-q>", "<C-S-Q>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		require("plugins.krs.launch_profiles").open_management_menu()
	end, { noremap = true, silent = true, desc = "Open Launch Profiles Management UI" })
end


-- Per-Project Task Manager & Code Runner (Ctrl + Shift + T / Ctrl + Shift + A)
-- Ctrl + Shift + A runs default task or kills old running task & reruns it
for _, lhs in ipairs({ "<C-S-t>", "<C-S-T>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		require("plugins.krs.tasks").open_task_menu()
	end, { noremap = true, silent = true, desc = "Open Project Task Menu" })
end

local function run_or_restart_task_handler()
	if vim.fn.mode() == "t" then
		pcall(vim.cmd, "stopinsert")
	end
	require("plugins.krs.tasks").run_default_or_menu()
end

for _, lhs in ipairs({ "<C-S-a>", "<C-S-A>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, run_or_restart_task_handler, {
		noremap = true,
		silent = true,
		desc = "Run default task or kill & rerun running task",
	})
end

vim.keymap.set("n", "<leader>ta", function()
	require("plugins.krs.tasks").open_task_menu()
end, { noremap = true, silent = true, desc = "Open Project Task Menu" })

-- Background task output windows (up to 4 concurrent long-running tasks,
-- e.g. `bun run dev`). Ctrl+1..4 toggles that slot's window; does nothing
-- if the slot is empty. Ctrl+` toggles whichever slot was last run/focused.
for i = 1, 4 do
	vim.keymap.set({ "n", "i", "v", "t" }, "<C-" .. i .. ">", function()
		require("plugins.krs.tasks").toggle_slot_window(i)
	end, { noremap = true, silent = true, desc = "Toggle task output slot " .. i })
end

local task_output_keys = { "<C-`>", "<C-S-o>", "<C-[>" }
for _, k in ipairs(task_output_keys) do
	vim.keymap.set({ "n", "i", "v", "t" }, k, function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		require("plugins.krs.tasks").toggle_last_slot_window()
	end, { noremap = true, silent = true, desc = "Toggle last task output window" })
end

-- Ctrl + Click a URL (in any buffer, e.g. task/terminal output) to open it in the browser
vim.keymap.set({ "n", "i", "v", "t" }, "<C-LeftMouse>", function()
	local mouse = vim.fn.getmousepos()
	if mouse.winid == 0 then
		return
	end
	vim.api.nvim_set_current_win(mouse.winid)
	pcall(vim.api.nvim_win_set_cursor, mouse.winid, { mouse.line, math.max(mouse.column - 1, 0) })
	local url = vim.fn.expand("<cWORD>"):match("https?://[^%s\"'<>%)%]]+")
	if url then
		vim.ui.open(url)
	end
end, { noremap = true, silent = true, desc = "Ctrl+Click: open URL under cursor in browser" })

-- Floating Desktop File Explorer (Ctrl + Shift + F)
vim.keymap.set({ "n", "i", "v" }, "<C-S-f>", function()
	require("plugins.krs.file_explorer").open_desktop_explorer()
end, { noremap = true, silent = true, desc = "Open Floating Desktop File Explorer" })

-- Floating WSL File Explorer
vim.keymap.set({ "n", "i", "v" }, "<leader>fw", function()
	require("plugins.krs.file_explorer").open_wsl_explorer()
end, { noremap = true, silent = true, desc = "Open Floating WSL File Explorer" })

vim.keymap.set({ "n", "v" }, "<leader>ff", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file or range" })

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

vim.keymap.set(
	"n",
	"<A-h>",
	safe_buf_navigate("BufferLineCyclePrev"),
	{ noremap = true, silent = true, desc = "Previous buffer" }
)
vim.keymap.set(
	"n",
	"<A-l>",
	safe_buf_navigate("BufferLineCycleNext"),
	{ noremap = true, silent = true, desc = "Next buffer" }
)
vim.keymap.set(
	"n",
	"<A-Left>",
	safe_buf_navigate("BufferLineCyclePrev"),
	{ noremap = true, silent = true, desc = "Previous buffer" }
)
vim.keymap.set(
	"n",
	"<A-Right>",
	safe_buf_navigate("BufferLineCycleNext"),
	{ noremap = true, silent = true, desc = "Next buffer" }
)

-- =========== Plugin Specifics =================
-- Neo-tree
-- Open/Close (Sidebar)
vim.keymap.set("n", "<C-S-Space>", ":Neotree toggle<CR>", { noremap = true, silent = true, desc = "Toggle Explorer" })

-- Floating inline rename box: opens a real (vim-editable) 1-line buffer next
-- to the symbol, prefilled with its current name. `:w` confirms and fires
-- the LSP rename; <Esc> or closing the window cancels.
-- F2: rename. Inside neo-tree uses its rename; in a code buffer with an
-- attached LSP renames the symbol under cursor; otherwise renames file on disk.
vim.keymap.set("n", "<F2>", function()
	if vim.bo.filetype == "neo-tree" then
		vim.api.nvim_feedkeys("r", "m", false)
		return
	end

	local has_lsp_rename = false
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if client:supports_method("textDocument/rename") then
			has_lsp_rename = true
			break
		end
	end

	if has_lsp_rename then
		local old_name = vim.fn.expand("<cword>")
		if old_name == "" then
			return
		end
		require("plugins.krs.input_modal").open({
			label = "LSP Rename",
			default_value = old_name,
			relative = "cursor",
			callback = function(ok, new_name)
				if ok and new_name and new_name ~= "" and new_name ~= old_name then
					vim.lsp.buf.rename(new_name)
				end
			end,
		})
		return
	end

	local old_path = vim.api.nvim_buf_get_name(0)
	if old_path == "" then
		vim.notify("Buffer has no file, cannot rename", vim.log.levels.WARN)
		return
	end

	local dir = vim.fn.fnamemodify(old_path, ":h")
	local old_name = vim.fn.fnamemodify(old_path, ":t")

	require("plugins.krs.input_modal").open({
		label = "Rename File",
		default_value = old_name,
		relative = "editor",
		callback = function(ok, new_name)
			if not ok or not new_name or new_name == "" or new_name == old_name then
				return
			end

			local new_path = dir .. "/" .. new_name

			if vim.fn.filereadable(new_path) == 1 then
				vim.notify("File already exists: " .. new_path, vim.log.levels.ERROR)
				return
			end

			vim.cmd("write")
			local success, err = os.rename(old_path, new_path)
			if not success then
				vim.notify("Error renaming file: " .. tostring(err), vim.log.levels.ERROR)
				return
			end

			vim.cmd("edit " .. vim.fn.fnameescape(new_path))
			vim.cmd("bdelete " .. vim.fn.fnameescape(old_path))
		end,
	})
end, { noremap = true, silent = true, desc = "Rename symbol or file" })

-- Alt+h / Ctrl+Shift+h flip the breakpoint under the cursor between enabled and
-- disabled, keeping it on the line (grey paw sign). Both keys already do
-- something else (cycle buffers, split left), and <C-S-h> is claimed by a lazy
-- `keys` spec in telescope.lua, so the mapping is installed on VimEnter — last
-- writer wins — and the previous mapping is replayed whenever the cursor line
-- has no breakpoint to flip.
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("KrsDapBreakpointEnableKeys", { clear = true }),
	callback = function()
		for _, lhs in ipairs({ "<A-h>", "<M-h>", "<C-S-h>", "<C-S-H>" }) do
			for _, mode in ipairs({ "n", "i", "v" }) do
				local prev = vim.fn.maparg(lhs, mode, false, true)
				local function fallback()
					if type(prev) ~= "table" then
						return
					end
					if prev.callback then
						prev.callback()
					elseif prev.rhs and prev.rhs ~= "" then
						local keys = vim.api.nvim_replace_termcodes(prev.rhs, true, true, true)
						vim.api.nvim_feedkeys(keys, prev.noremap == 1 and "n" or "m", false)
					end
				end
				vim.keymap.set(mode, lhs, function()
					local ok, mod = pcall(require, "plugins.krs.dap_breakpoints")
					if ok and mod.toggle_enabled({ silent = true }) then
						return
					end
					fallback()
				end, { noremap = true, silent = true, desc = "Enable/Disable Breakpoint" })
			end
		end
	end,
})

-- ============================================================================
-- 🦊 KRSNVIMSCRIPT KEYMAPS: Ctrl+, (Run Script) & Ctrl+Shift+, (Wiki Docs)
-- ============================================================================
local function run_krsnvimscript_handler()
	if vim.fn.mode() == "t" then
		pcall(vim.cmd, "stopinsert")
	end
	local buf_name = vim.api.nvim_buf_get_name(0)
	if buf_name:match("%.krsnvim$") or vim.bo.filetype == "krsnvim" then
		vim.cmd("w")
		require("krsnvim")
		vim.notify("🦊 Running krsnvimscript: " .. vim.fn.fnamemodify(buf_name, ":t"), vim.log.levels.INFO)
		dofile(buf_name)
	else
		require("plugins.krs.launch_profiles").open_management_menu()
	end
end

for _, lhs in ipairs({ "<C-,>", "<C-comma>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, run_krsnvimscript_handler, {
		noremap = true,
		silent = true,
		desc = "Run current .krsnvim file with krsnvimscript",
	})
end

for _, lhs in ipairs({ "<C-S-,>", "<C-S-comma>", "<C-?>" }) do
	vim.keymap.set({ "n", "i", "v", "t" }, lhs, function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		require("krsnvim").wiki.open()
	end, {
		noremap = true,
		silent = true,
		desc = "Open krsnvimscript Floating Wiki Documentation",
	})
end

