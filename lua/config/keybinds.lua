-- GLOBAL CONFIG
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

-- VSCode Migration (Old habits never die)
vim.keymap.set("n", "<C-_>", "gcc", { remap = true, desc = "Comment line" })
vim.keymap.set("v", "<C-_>", "gc", { remap = true, desc = "Comment selection" })

vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<Cmd>w<CR>", { noremap = true, silent = true, desc = "Save file" })

-- QOL Features & Clipboard (Ctrl+C = Copiar, Ctrl+V = Pegar del sistema)
vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, desc = "Copiar al portapapeles" })
vim.keymap.set(
	{ "n", "v" },
	"<C-v>",
	'"+p',
	{ noremap = true, silent = true, desc = "Pegar del portapapeles del sistema" }
)
vim.keymap.set(
	{ "i", "c" },
	"<C-v>",
	"<C-r>+",
	{ noremap = true, silent = true, desc = "Pegar del portapapeles del sistema" }
)
-- Undo / Redo (Ctrl+Z = Deshacer, Ctrl+Y / Ctrl+Shift+Z = Rehacer)
vim.keymap.set("n", "<C-z>", "u", { noremap = true, silent = true, desc = "Deshacer (Undo)" })
vim.keymap.set("v", "<C-z>", "<Esc>u", { noremap = true, silent = true, desc = "Deshacer (Undo)" })
vim.keymap.set("i", "<C-z>", "<C-o>u", { noremap = true, silent = true, desc = "Deshacer (Undo)" })

vim.keymap.set("n", "<C-y>", "<C-r>", { noremap = true, silent = true, desc = "Rehacer (Redo)" })
vim.keymap.set("n", "<C-S-z>", "<C-r>", { noremap = true, silent = true, desc = "Rehacer (Redo)" })
vim.keymap.set("i", "<C-y>", "<C-o><C-r>", { noremap = true, silent = true, desc = "Rehacer (Redo)" })
vim.keymap.set("i", "<C-S-z>", "<C-o><C-r>", { noremap = true, silent = true, desc = "Rehacer (Redo)" })

-- Movements across panels & split windows
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
vim.keymap.set("n", "<C-S-k>", "<C-w>k", { desc = "Move to top window" })
vim.keymap.set("n", "<C-S-j>", "<C-w>j", { desc = "Move to bottom window" })

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

-- Errors / Diagnostics
local function show_diagnostic_float()
	vim.diagnostic.open_float({ border = "rounded", scope = "cursor", focusable = true })
end

vim.keymap.set(
	{ "n", "i", "v" },
	"<A-k>",
	show_diagnostic_float,
	{ noremap = true, silent = true, desc = "Show detailed diagnostic info" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<M-k>",
	show_diagnostic_float,
	{ noremap = true, silent = true, desc = "Show detailed diagnostic info" }
)
vim.keymap.set("n", "<leader>k", show_diagnostic_float, { desc = "Show diagnostic info" })
vim.keymap.set("n", "<leader>u", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>o", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- VSCode Quick Fix / Suggestions with Ctrl + . (Mini Dropdown at Caret position)
local function cursor_ui_select(items, opts, on_choice)
	opts = opts or {}
	local prompt = opts.prompt or "Acciones de Código Disponibles:"
	prompt = prompt:gsub("^%s*", ""):gsub("%s*$", "")

	local formatted_items = {}
	for i, item in ipairs(items) do
		local text = opts.format_item and opts.format_item(item) or tostring(item)
		table.insert(formatted_items, string.format("%d. %s", i, text))
	end

	if #formatted_items == 0 then
		vim.notify("No hay sugerencias de código disponibles aquí", vim.log.levels.INFO, { title = "LSP Code Actions" })
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

	-- Crear ventana flotante anclada AL CURSOR (caret position)
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
		vim.notify(
			"No hay ningún servidor LSP activo para este archivo",
			vim.log.levels.WARN,
			{ title = "LSP Code Actions" }
		)
		return
	end

	local orig_select = vim.ui.select
	vim.ui.select = function(items, opts, on_choice)
		vim.ui.select = orig_select
		if not items or #items == 0 then
			vim.notify(
				"No hay sugerencias ni acciones de código disponibles aquí",
				vim.log.levels.INFO,
				{ title = "LSP Code Actions" }
			)
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
	end
end
local function dap_continue()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.continue()
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

vim.keymap.set(
	{ "n", "i", "v" },
	"<A-b>",
	dap_toggle_breakpoint,
	{ noremap = true, silent = true, desc = "Toggle Breakpoint" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<M-b>",
	dap_toggle_breakpoint,
	{ noremap = true, silent = true, desc = "Toggle Breakpoint" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<C-S-s>",
	dap_continue,
	{ noremap = true, silent = true, desc = "Start/Continue Debugging" }
)
vim.keymap.set(
	{ "n", "i", "v" },
	"<C-S-x>",
	dap_terminate,
	{ noremap = true, silent = true, desc = "Terminate Debugger" }
)

-- Per-Project Task Manager & Code Runner (Ctrl + Shift + A)
vim.keymap.set({ "n", "i", "v" }, "<C-S-a>", function()
	require("config.krs.tasks").run_default_or_menu()
end, { noremap = true, silent = true, desc = "Run Default Project Task" })

vim.keymap.set("n", "<leader>ta", function()
	require("config.krs.tasks").open_task_menu()
end, { noremap = true, silent = true, desc = "Open Project Task Menu" })

vim.keymap.set({ "n", "v" }, "<leader>f", function()
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
