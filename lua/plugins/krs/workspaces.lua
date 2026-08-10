-- ============================================================================
-- 🦊 KRS PLUGIN: Custom Workspace and Session Manager (Workspace Manager)
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Uses Neovim `mksession!` to save exact state of windows, tabs, buffers, and layouts.
-- 2. Stores saved sessions in a dedicated directory at `stdpath("data")/workspaces`.
-- 3. Maintains a centralized `index.json` file with detailed workspace information (paths, dates, open buffers).
-- 4. Exposes an interactive selection interface in Telescope (`<C-S-w>`, `:WorkspaceSelect`, `:Workspaces`):
--      [Enter]  -> Load selected workspace
--      [d]      -> Delete workspace
--      [r]      -> Rename workspace
--      [a]      -> Save current state as new workspace
--      [s]      -> Overwrite selected workspace with current state
--      [g]      -> Toggle between Current Project workspaces vs All Workspaces
--      [1..9]   -> Quick load workspace by slot index (Harpoon style)
-- 5. Provides user commands and `<C-S-m>` shortcut to return to Main Menu (Alpha Dashboard).
-- ============================================================================

local M = {}

-- Session storage directory
local function get_storage_dir()
	local dir = vim.fn.stdpath("data") .. "/workspaces"
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	return dir
end

-- JSON index file path
local function get_index_path()
	return get_storage_dir() .. "/index.json"
end

-- Read JSON index file
local function load_index()
	local path = get_index_path()
	local f = io.open(path, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return {}
	end
	local ok, res = pcall(vim.json.decode, content)
	return ok and type(res) == "table" and res or {}
end

-- Save JSON index file
local function save_index(index)
	local path = get_index_path()
	local f = io.open(path, "w")
	if not f then
		return false
	end
	f:write(vim.json.encode(index))
	f:close()
	return true
end

-- Format relative time (e.g. "just now", "5 mins ago", "2 hours ago")
local function format_relative_time(timestamp)
	if not timestamp then
		return ""
	end
	local diff = os.time() - timestamp
	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		local mins = math.floor(diff / 60)
		return string.format("%d min%s ago", mins, mins > 1 and "s" or "")
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return string.format("%d hour%s ago", hours, hours > 1 and "s" or "")
	else
		local days = math.floor(diff / 86400)
		return string.format("%d day%s ago", days, days > 1 and "s" or "")
	end
end

-- Get open buffer paths relative to working directory
local function get_current_buffers()
	local buflist = {}
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.fn.buflisted(b) == 1 then
			local name = vim.api.nvim_buf_get_name(b)
			if name ~= "" and vim.bo[b].buftype == "" then
				table.insert(buflist, vim.fn.fnamemodify(name, ":."))
			end
		end
	end
	return buflist
end

-- Configure Neovim session options
local function set_session_options()
	vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
end

-- Save current session to .vim file. Returns ok, err, neotree_was_open
local function save_session_file(session_path)
	set_session_options()

	-- Temporarily close Neo-tree before saving session to prevent split conflicts
	local neotree_was_open = false
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "neo-tree" then
			neotree_was_open = true
			break
		end
	end

	if neotree_was_open then
		pcall(vim.cmd, "Neotree close")
	end

	local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_path))

	if neotree_was_open then
		pcall(vim.cmd, "Neotree show")
	end

	return ok, err, neotree_was_open
end

-- Logic to save a workspace
function M.save_workspace(name, callback)
	local cwd = vim.fn.getcwd()
	local cwd_name = vim.fn.fnamemodify(cwd, ":t")
	local index = load_index()

	local perform_save = function(ws_name)
		if not ws_name or ws_name == "" then
			local count = 1
			for _, item in ipairs(index) do
				if item.cwd == cwd then
					count = count + 1
				end
			end
			ws_name = string.format("%s (Workspace %d)", cwd_name, count)
		end

		local ws_item = nil
		for _, item in ipairs(index) do
			if item.name:lower() == ws_name:lower() and item.cwd == cwd then
				ws_item = item
				break
			end
		end

		local id = ws_item and ws_item.id or ("ws_" .. os.time() .. "_" .. math.random(1000, 9999))
		local session_path = get_storage_dir() .. "/" .. id .. ".vim"

		local ok, err, neotree_open = save_session_file(session_path)
		if not ok then
			vim.notify("Error saving workspace: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		local buffers = get_current_buffers()
		local tab_count = #vim.api.nvim_list_tabpages()

		if ws_item then
			ws_item.updated_at = os.time()
			ws_item.buffers = buffers
			ws_item.tab_count = tab_count
			ws_item.session_file = session_path
			ws_item.neotree_open = neotree_open
		else
			ws_item = {
				id = id,
				name = ws_name,
				cwd = cwd,
				cwd_name = cwd_name,
				created_at = os.time(),
				updated_at = os.time(),
				session_file = session_path,
				buffers = buffers,
				tab_count = tab_count,
				neotree_open = neotree_open,
			}
			table.insert(index, 1, ws_item)
		end

		save_index(index)
		vim.notify(
			"Workspace '" .. ws_name .. "' saved successfully!",
			vim.log.levels.INFO,
			{ title = "KRS Workspaces" }
		)
		if callback then
			callback()
		end
	end

	if name and name ~= "" then
		perform_save(name)
	else
		local existing_for_cwd = nil
		for _, item in ipairs(index) do
			if item.cwd == cwd then
				existing_for_cwd = item
				break
			end
		end

		if existing_for_cwd then
			perform_save(existing_for_cwd.name)
		else
			pcall(vim.ui.input, {
				prompt = "New Workspace Name: ",
				default = cwd_name .. " - " .. os.date("%H:%M"),
			}, function(input_name)
				if input_name ~= nil and input_name ~= "" then
					perform_save(input_name)
				end
			end)
		end
	end
end

-- Logic to load a workspace
function M.load_workspace(ws_or_identifier)
	local index = load_index()
	local target = nil

	if type(ws_or_identifier) == "table" then
		target = ws_or_identifier
	elseif type(ws_or_identifier) == "number" then
		local cwd = vim.fn.getcwd()
		local count = 0
		for _, item in ipairs(index) do
			if item.cwd == cwd then
				count = count + 1
				if count == ws_or_identifier then
					target = item
					break
				end
			end
		end
	elseif type(ws_or_identifier) == "string" and ws_or_identifier ~= "" then
		for _, item in ipairs(index) do
			if item.id == ws_or_identifier or item.name:lower() == ws_or_identifier:lower() then
				target = item
				break
			end
		end
	end

	if not target then
		vim.notify("Workspace not found", vim.log.levels.WARN, { title = "KRS Workspaces" })
		return false
	end

	if vim.fn.filereadable(target.session_file) == 0 then
		vim.notify(
			"Session file does not exist: " .. target.session_file,
			vim.log.levels.ERROR,
			{ title = "KRS Workspaces" }
		)
		return false
	end

	if target.cwd and vim.fn.getcwd() ~= target.cwd then
		pcall(vim.api.nvim_set_current_dir, target.cwd)
	end

	pcall(vim.cmd, "Neotree close")

	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype ~= "terminal" then
			pcall(vim.api.nvim_buf_delete, b, { force = true })
		end
	end

	local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(target.session_file))
	if not ok then
		vim.notify("Error loading session: " .. tostring(err), vim.log.levels.ERROR, { title = "KRS Workspaces" })
		return false
	end

	if target.neotree_open then
		pcall(vim.cmd, "Neotree show")
	end

	target.updated_at = os.time()
	save_index(index)

	vim.notify("Workspace '" .. target.name .. "' loaded!", vim.log.levels.INFO, { title = "KRS Workspaces" })
	return true
end

-- Logic to delete a workspace
function M.delete_workspace(ws_or_id, callback)
	local index = load_index()
	local target_idx = nil
	local target = nil

	for idx, item in ipairs(index) do
		if type(ws_or_id) == "table" and item.id == ws_or_id.id then
			target_idx = idx
			target = item
			break
		elseif type(ws_or_id) == "string" and (item.id == ws_or_id or item.name:lower() == ws_or_id:lower()) then
			target_idx = idx
			target = item
			break
		end
	end

	if not target then
		vim.notify("Workspace not found to delete", vim.log.levels.WARN, { title = "KRS Workspaces" })
		return
	end

	local confirm = vim.fn.confirm("Delete workspace '" .. target.name .. "'?", "&Yes\n&No", 2)
	if confirm == 1 then
		if vim.fn.filereadable(target.session_file) == 1 then
			os.remove(target.session_file)
		end
		table.remove(index, target_idx)
		save_index(index)
		vim.notify("Workspace '" .. target.name .. "' deleted.", vim.log.levels.INFO, { title = "KRS Workspaces" })
		if callback then
			callback()
		end
	end
end

-- Logic to rename a workspace
function M.rename_workspace(ws_or_id, callback)
	local index = load_index()
	local target = nil

	for _, item in ipairs(index) do
		if type(ws_or_id) == "table" and item.id == ws_or_id.id then
			target = item
			break
		elseif type(ws_or_id) == "string" and (item.id == ws_or_id or item.name:lower() == ws_or_id:lower()) then
			target = item
			break
		end
	end

	if not target then
		vim.notify("Workspace not found to rename", vim.log.levels.WARN, { title = "KRS Workspaces" })
		return
	end

	pcall(
		vim.ui.input,
		{ prompt = "New name for '" .. target.name .. "': ", default = target.name },
		function(new_name)
			if new_name and new_name ~= "" and new_name ~= target.name then
				target.name = new_name
				target.updated_at = os.time()
				save_index(index)
				vim.notify("Workspace renamed to '" .. new_name .. "'", vim.log.levels.INFO, { title = "KRS Workspaces" })
				if callback then
					callback()
				end
			end
		end
	)
end

-- Close session and return to Main Menu (Alpha Dashboard)
function M.close_to_menu()
	if vim.bo.filetype == "alpha" then
		vim.notify("Already at main menu", vim.log.levels.INFO, { title = "KRS Workspaces" })
		return
	end

	local close_all_and_open_alpha = function()
		pcall(vim.cmd, "Neotree close")
		pcall(vim.cmd, "only")
		vim.cmd("Alpha")
		local alpha_buf = vim.api.nvim_get_current_buf()
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if b ~= alpha_buf and vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype ~= "alpha" then
				pcall(vim.api.nvim_buf_delete, b, { force = true })
			end
		end
	end

	local choices = {
		"1. 💾 Save Workspace and return to Menu",
		"2. 🚪 Return to Menu without saving",
		"3. ❌ Cancel",
	}

	pcall(vim.ui.select, choices, {
		prompt = "🦊 Close session and return to Main Menu (Dashboard)?",
	}, function(choice)
		if not choice or choice:match("^3") then
			return
		end

		if choice:match("^1") then
			M.save_workspace(nil, close_all_and_open_alpha)
		elseif choice:match("^2") then
			close_all_and_open_alpha()
		end
	end)
end

-- Interactive Selection Interface in Telescope
function M.select_workspace()
	local ok_telescope, telescope = pcall(require, "telescope")
	if not ok_telescope then
		vim.notify("Telescope is not available", vim.log.levels.ERROR, { title = "KRS Workspaces" })
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local previewers = require("telescope.previewers")
	local themes = require("telescope.themes")

	local current_cwd = vim.fn.getcwd()
	local show_all = false
	do
		-- No project opened yet (nothing saved under this cwd) -> default to showing everything
		local index = load_index()
		local has_for_cwd = false
		for _, item in ipairs(index) do
			if item.cwd == current_cwd then
				has_for_cwd = true
				break
			end
		end
		if not has_for_cwd then
			show_all = true
		end
	end

	local function get_results()
		local index = load_index()
		local results = {}
		local slot = 1

		table.sort(index, function(a, b)
			local a_curr = a.cwd == current_cwd and 1 or 0
			local b_curr = b.cwd == current_cwd and 1 or 0
			if a_curr ~= b_curr then
				return a_curr > b_curr
			end
			return (a.updated_at or 0) > (b.updated_at or 0)
		end)

		for _, item in ipairs(index) do
			if show_all or item.cwd == current_cwd then
				item.slot_idx = slot
				table.insert(results, item)
				slot = slot + 1
			end
		end
		return results
	end

	local function create_picker()
		local items = get_results()

		pickers
			.new(
				themes.get_dropdown({
					prompt_title = string.format(
						" 🦊 Workspaces [%s] (a: New | d: Delete | r: Rename | s: Overwrite | g: %s) ",
						vim.fn.fnamemodify(current_cwd, ":t"),
						show_all and "Current Project Only" or "View All"
					),
					width = 0.85,
					results_title = "Saved Workspaces",
				}),
				{
					finder = finders.new_table({
						results = items,
						entry_maker = function(entry)
							local time_str = format_relative_time(entry.updated_at)
							local is_curr = entry.cwd == current_cwd
							local tag = is_curr and "📍" or "📁"
							local buf_count = entry.buffers and #entry.buffers or 0
							local tab_count = entry.tab_count or 1

							local display_text = string.format(
								"[%d] %s  %s %s  •  %d buffer%s, %d tab%s  (%s)",
								entry.slot_idx,
								entry.name,
								tag,
								entry.cwd_name or "",
								buf_count,
								buf_count == 1 and "" or "s",
								tab_count,
								tab_count == 1 and "" or "s",
								time_str
							)

							return {
								value = entry,
								display = display_text,
								ordinal = entry.name .. " " .. (entry.cwd_name or "") .. " " .. tostring(entry.slot_idx),
							}
						end,
					}),
					sorter = conf.generic_sorter({}),
					previewer = previewers.new_buffer_previewer({
						title = "Workspace Details",
						define_preview = function(self, entry)
							local ws = entry.value
							local lines = {
								"📌 Name:         " .. ws.name,
								"📁 Project:      " .. (ws.cwd_name or ""),
								"🌐 CWD Path:     " .. ws.cwd,
								"🕒 Updated:      " .. os.date("%Y-%m-%d %H:%M:%S", ws.updated_at or os.time()),
								"📑 Tabs:         " .. tostring(ws.tab_count or 1),
								"",
								"📄 Saved Files (" .. #(ws.buffers or {}) .. "):",
								"----------------------------------------",
							}
							if ws.buffers and #ws.buffers > 0 then
								for i, buf in ipairs(ws.buffers) do
									table.insert(lines, string.format("  %d. %s", i, buf))
								end
							else
								table.insert(lines, "  (no files)")
							end

							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
							vim.api.nvim_set_option_value("filetype", "markdown", { buf = self.state.bufnr })
						end,
					}),
					attach_mappings = function(prompt_bufnr, map)
						actions.select_default:replace(function()
							local selection = action_state.get_selected_entry()
							actions.close(prompt_bufnr)
							if selection and selection.value then
								M.load_workspace(selection.value)
							end
						end)

						local delete_action = function()
							local selection = action_state.get_selected_entry()
							if selection and selection.value then
								M.delete_workspace(selection.value, function()
									actions.close(prompt_bufnr)
									vim.schedule(function()
										M.select_workspace()
									end)
								end)
							end
						end
						map("i", "<C-d>", delete_action)
						map("n", "d", delete_action)
						map("i", "<Del>", delete_action)

						local rename_action = function()
							local selection = action_state.get_selected_entry()
							if selection and selection.value then
								actions.close(prompt_bufnr)
								vim.schedule(function()
									M.rename_workspace(selection.value, function()
										M.select_workspace()
									end)
								end)
							end
						end
						map("i", "<C-r>", rename_action)
						map("n", "r", rename_action)
						map("n", "<F2>", rename_action)

						local add_action = function()
							actions.close(prompt_bufnr)
							vim.schedule(function()
								M.save_workspace()
							end)
						end
						map("i", "<C-a>", add_action)
						map("n", "a", add_action)

						local save_overwrite_action = function()
							local selection = action_state.get_selected_entry()
							if selection and selection.value then
								actions.close(prompt_bufnr)
								vim.schedule(function()
									M.save_workspace(selection.value.name)
								end)
							end
						end
						map("i", "<C-s>", save_overwrite_action)
						map("n", "s", save_overwrite_action)

						local toggle_all_action = function()
							show_all = not show_all
							actions.close(prompt_bufnr)
							vim.schedule(function()
								M.select_workspace()
							end)
						end
						map("i", "<C-g>", toggle_all_action)
						map("n", "g", toggle_all_action)

						for n = 1, 9 do
							map("n", tostring(n), function()
								local entry_list = get_results()
								if entry_list[n] then
									actions.close(prompt_bufnr)
									M.load_workspace(entry_list[n])
								else
									vim.notify("Workspace #" .. n .. " does not exist", vim.log.levels.WARN, { title = "KRS Workspaces" })
								end
							end)
						end

						return true
					end,
				}
			)
			:find()
	end

	create_picker()
end

_G.Workspaces = M

-- Plugin Specification for Lazy.nvim
local plugin_spec = {
	name = "workspaces",
	dir = vim.fn.stdpath("config"),
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		-- User Commands
		vim.api.nvim_create_user_command("WorkspaceSave", function(opts)
			M.save_workspace(opts.args ~= "" and opts.args or nil)
		end, { nargs = "?", desc = "Save state as workspace" })

		vim.api.nvim_create_user_command("WorkspaceLoad", function(opts)
			local arg = opts.args
			if arg == "" then
				M.select_workspace()
			else
				local num = tonumber(arg)
				M.load_workspace(num or arg)
			end
		end, { nargs = "?", desc = "Load saved workspace" })

		vim.api.nvim_create_user_command("WorkspaceDelete", function(opts)
			M.delete_workspace(opts.args ~= "" and opts.args or nil)
		end, { nargs = "?", desc = "Delete workspace" })

		vim.api.nvim_create_user_command("WorkspaceRename", function(opts)
			local args = vim.split(opts.args, "%s+", { trimempty = true })
			if #args >= 2 then
				M.rename_workspace(args[1], function() end)
			else
				M.select_workspace()
			end
		end, { nargs = "*", desc = "Rename workspace" })

		vim.api.nvim_create_user_command("WorkspaceSelect", function()
			M.select_workspace()
		end, {})

		vim.api.nvim_create_user_command("Workspaces", function()
			M.select_workspace()
		end, {})

		vim.api.nvim_create_user_command("WorkspaceClose", function()
			M.close_to_menu()
		end, { desc = "Close session and return to main menu" })

		vim.api.nvim_create_user_command("WorkspaceMenu", function()
			M.close_to_menu()
		end, { desc = "Close session and return to main menu" })

		-- Global Keymaps
		vim.keymap.set({ "n", "i", "v", "t" }, "<C-S-w>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.select_workspace()
		end, { noremap = true, silent = true, desc = "Open Workspaces UI" })

		vim.keymap.set({ "n", "i", "v", "t" }, "<C-S-W>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.select_workspace()
		end, { noremap = true, silent = true, desc = "Open Workspaces UI" })

		vim.keymap.set({ "n", "i", "v", "t" }, "<C-S-m>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.close_to_menu()
		end, { noremap = true, silent = true, desc = "Close and return to Menu" })

		vim.keymap.set("n", "<leader>ws", function()
			M.save_workspace()
		end, { desc = "Save Workspace" })

		vim.keymap.set("n", "<leader>ww", function()
			M.select_workspace()
		end, { desc = "Select Workspace" })

		vim.keymap.set("n", "<leader>wm", function()
			M.close_to_menu()
		end, { desc = "Close and return to Menu" })

		for i = 1, 9 do
			vim.keymap.set("n", "<leader>w" .. i, function()
				M.load_workspace(i)
			end, { desc = "Load Workspace slot " .. i })
		end
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

