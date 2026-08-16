-- ============================================================================
-- KRS PLUGIN: Documentation Center & Wiki Modal (Ctrl + Shift + D).
-- ============================================================================
-- WHAT IT DOES
--   An interactive dual-pane Wikipedia modal for KrsVim documentation.
--   Left panel: Categorized index of every guide, how-to, and architecture doc.
--   Right panel: Live markdown document viewer with syntax highlighting.
-- ============================================================================

local ui = require("krs.core.ui")
local zindex = require("krs.core.z_index")
local path_util = require("krs.core.path")

local M = {}

M.settings = {
	keys = {
		open = { "<C-S-d>", "<C-S-D>" },
	},
	docs_dir = vim.fn.stdpath("config") .. "/docs",
	left_width_ratio = 0.32,
	min_left_width = 30,
}

--- Document category catalog matching docs/ layout.
M.categories = {
	{
		title = "🏁 Getting Started",
		docs = {
			{ name = "Wiki Home & Overview", file = "index.md" },
			{ name = "Installation & Setup", file = "installation.md" },
			{ name = "Keybinds Reference", file = "keybinds.md" },
			{ name = "Plugin Inventory", file = "plugins.md" },
		},
	},
	{
		title = "🎓 How-To & Extension",
		docs = {
			{ name = "How-To & Customization Guide", file = "how-to-customize-editor.md" },
			{ name = "How to Create Local Plugins", file = "how-to-create-local-plugin.md" },
			{ name = "How to Add a New Language", file = "adding-language.md" },
		},
	},
	{
		title = "📖 Explanations & Architecture",
		docs = {
			{ name = "System Architecture", file = "architecture.md" },
			{ name = "Module Architecture", file = "module-architecture.md" },
			{ name = "Dynamic Z-Index Stack", file = "z-index.md" },
			{ name = "Testing & QA Suite", file = "testing.md" },
		},
	},
	{
		title = "🚀 Building & Debugging",
		docs = {
			{ name = "Task Runner (tasks.json)", file = "tasks.md" },
			{ name = "Launch Profiles (launch.json)", file = "launch-profiles.md" },
			{ name = "Debug Adapters (DAP)", file = "debug-adapters.md" },
			{ name = "Persistent Breakpoints", file = "breakpoints.md" },
		},
	},
	{
		title = "🎨 UI & Workflow",
		docs = {
			{ name = "Git Control Center", file = "git-center.md" },
			{ name = "File Explorers & Neo-tree", file = "file-explorer.md" },
			{ name = "Multi-Terminal Manager", file = "terminals.md" },
			{ name = "Workspaces & Sessions", file = "workspaces.md" },
			{ name = "Command Palette", file = "command-palette.md" },
			{ name = "Color Palette & Themes", file = "color-palette.md" },
			{ name = "Editor Quality of Life", file = "editor-qol.md" },
		},
	},
	{
		title = "🧬 Code Helpers",
		docs = {
			{ name = "Tailwind Classes Organizer", file = "tailwind-organizer.md" },
			{ name = "Modular Type Injector", file = "type-injector.md" },
			{ name = "Input Modal Component", file = "input-modal.md" },
			{ name = "JSON Schemas Catalog", file = "schemas-json.md" },
			{ name = "TOML Schemas Catalog", file = "schemas-toml.md" },
		},
	},
}

--- Active session state.
local state = {
	is_open = false,
	left_buf = nil,
	left_win = nil,
	right_buf = nil,
	right_win = nil,
	active_doc_file = nil,
	items = {}, -- Flat list of { type = "header"|"doc", title = ..., file = ... }
}

--- Flatten categories into list items for navigation index.
local function build_flat_items()
	local items = {}
	for _, cat in ipairs(M.categories) do
		table.insert(items, { type = "header", title = cat.title })
		for _, doc in ipairs(cat.docs) do
			table.insert(items, { type = "doc", title = "  📄 " .. doc.name, file = doc.file })
		end
	end
	return items
end

--- Loads and renders doc file content in right preview window.
--- @param filename string
local function load_document(filename)
	if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
		return
	end

	local filepath = path_util.join(M.settings.docs_dir, filename)
	local lines = {}
	local f = io.open(filepath, "r")
	if f then
		for line in f:lines() do
			table.insert(lines, line)
		end
		f:close()
	else
		table.insert(lines, "# Document Not Found")
		table.insert(lines, "")
		table.insert(lines, "Could not locate documentation file: " .. filepath)
	end

	vim.bo[state.right_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, lines)
	vim.bo[state.right_buf].modifiable = false
	vim.bo[state.right_buf].filetype = "markdown"

	state.active_doc_file = filename
end

--- Closes documentation modal cleanly.
function M.close()
	if not state.is_open then
		return
	end

	if state.left_win and vim.api.nvim_win_is_valid(state.left_win) then
		pcall(vim.api.nvim_win_close, state.left_win, true)
	end
	if state.right_win and vim.api.nvim_win_is_valid(state.right_win) then
		pcall(vim.api.nvim_win_close, state.right_win, true)
	end

	zindex.unregister("wiki_modal")

	state.is_open = false
	state.left_win = nil
	state.right_win = nil
	state.left_buf = nil
	state.right_buf = nil
end

--- Opens Documentation Center modal.
function M.open()
	if state.is_open then
		M.close()
		return
	end

	state.items = build_flat_items()

	local editor_w = vim.o.columns
	local editor_h = vim.o.lines - 2

	local modal_w = math.floor(editor_w * 0.88)
	local modal_h = math.floor(editor_h * 0.85)

	local left_w = math.max(M.settings.min_left_width, math.floor(modal_w * M.settings.left_width_ratio))
	local right_w = modal_w - left_w - 3

	local top = math.floor((editor_h - modal_h) / 2)
	local left = math.floor((editor_w - modal_w) / 2)

	local z_base = zindex.get_zindex("wiki_modal")

	-- Create Left Index Buffer & Win
	state.left_buf = ui.scratch_buffer({ modifiable = true, filetype = "krsdocindex" })
	local index_lines = {}
	for _, item in ipairs(state.items) do
		table.insert(index_lines, item.title)
	end
	vim.api.nvim_buf_set_lines(state.left_buf, 0, -1, false, index_lines)
	vim.bo[state.left_buf].modifiable = false

	state.left_win = vim.api.nvim_open_win(state.left_buf, true, {
		relative = "editor",
		row = top,
		col = left,
		width = left_w,
		height = modal_h,
		style = "minimal",
		border = "rounded",
		title = " 📚 KrsVim Wiki Index ",
		title_pos = "center",
		zindex = z_base,
	})

	-- Create Right Document Reader Buffer & Win
	state.right_buf = ui.scratch_buffer({ modifiable = true, filetype = "markdown" })
	state.right_win = vim.api.nvim_open_win(state.right_buf, false, {
		relative = "editor",
		row = top,
		col = left + left_w + 2,
		width = right_w,
		height = modal_h,
		style = "minimal",
		border = "rounded",
		title = " 📖 Document Reader ",
		title_pos = "center",
		zindex = z_base,
	})

	vim.wo[state.left_win].cursorline = true
	vim.wo[state.right_win].cursorline = false
	vim.wo[state.right_win].wrap = true

	state.is_open = true

	-- Load initial document (index.md)
	load_document("index.md")

	-- Set up cursor movement listener on index list for live document preview
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = state.left_buf,
		callback = function()
			if not state.is_open then
				return
			end
			local line = vim.api.nvim_win_get_cursor(state.left_win)[1]
			local item = state.items[line]
			if item and item.type == "doc" and item.file then
				load_document(item.file)
			end
		end,
	})

	-- Keybindings for Modal Navigation
	local function follow_link_in_reader()
		local cur_win = vim.api.nvim_get_current_win()
		if cur_win ~= state.right_win then
			return
		end

		local cursor = vim.api.nvim_win_get_cursor(state.right_win)
		local row = cursor[1]
		local lines = vim.api.nvim_buf_get_lines(state.right_buf, row - 1, row, false)
		local line = lines[1] or ""

		local target = line:match("%[[^%]]+%]%(([^%)]+)%)")
		if not target then
			target = line:match("(https?://%S+)")
		end

		if not target then
			vim.notify("No markdown link found on this line", vim.log.levels.WARN, { title = "Wiki Reader" })
			return
		end

		if target:match("^https?://") then
			pcall(vim.ui.open, target)
			vim.notify("🌐 Opening web link: " .. target, vim.log.levels.INFO)
			return
		end

		local clean_file = target:gsub("^file:///", ""):gsub("#.*$", ""):gsub("^.*/", "")
		if clean_file:match("%.md$") then
			load_document(clean_file)
			-- Sync left index selection if match found
			for idx, item in ipairs(state.items) do
				if item.file == clean_file then
					pcall(vim.api.nvim_win_set_cursor, state.left_win, { idx, 0 })
					break
				end
			end
		end
	end

	local function map_keys(buf, win)
		local opts = { noremap = true, silent = true, buffer = buf }

		-- Close keys
		for _, k in ipairs({ "q", "<Esc>", "<C-S-d>", "<C-S-D>" }) do
			vim.keymap.set({ "n", "v", "i", "t" }, k, M.close, opts)
		end

		-- Panel Switch
		vim.keymap.set("n", "<Tab>", function()
			if vim.api.nvim_get_current_win() == state.left_win then
				vim.api.nvim_set_current_win(state.right_win)
			else
				vim.api.nvim_set_current_win(state.left_win)
			end
		end, opts)

		vim.keymap.set("n", "<C-h>", function()
			vim.api.nvim_set_current_win(state.left_win)
		end, opts)

		vim.keymap.set("n", "<C-l>", function()
			vim.api.nvim_set_current_win(state.right_win)
		end, opts)
	end

	map_keys(state.left_buf, state.left_win)
	map_keys(state.right_buf, state.right_win)

	-- Link follow keymaps inside right reader buffer
	local reader_opts = { noremap = true, silent = true, buffer = state.right_buf }
	vim.keymap.set("n", "<CR>", follow_link_in_reader, reader_opts)
	vim.keymap.set("n", "<C-k>", follow_link_in_reader, reader_opts)
	vim.keymap.set("n", "gx", follow_link_in_reader, reader_opts)
	vim.keymap.set("n", "K", follow_link_in_reader, reader_opts)
end

function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	vim.api.nvim_create_user_command("KrsWiki", M.open, { desc = "Open KrsVim Wiki Documentation Modal" })
	vim.api.nvim_create_user_command("NvimWiki", M.open, { desc = "Open KrsVim Wiki Documentation Modal" })

	for _, k in ipairs(M.settings.keys.open) do
		vim.keymap.set({ "n", "v", "i", "t" }, k, M.open, { desc = "Open Documentation Center Wiki" })
	end
end

-- LAZY.NVIM SPEC
local plugin_spec = {
	name = "krs_wiki_modal",
	dir = require("krs.core.lazyspec").for_module(),
	cmd = { "KrsWiki", "NvimWiki" },
	keys = { { "<C-S-d>", mode = { "n", "v", "i", "t" }, desc = "Open Documentation Center Wiki" } },
	config = M.setup,
}

return setmetatable(plugin_spec, { __index = M })
