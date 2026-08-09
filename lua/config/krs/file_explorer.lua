-- ============================================================================
-- 🦊 KRS CONFIG: Native Floating File Explorer (Pure Lua Telescope)
-- ============================================================================
-- 1. 100% Native in Lua without external binaries (avoids 'Executable not found' errors).
-- 2. Defaults to user's Desktop directory (Cross-platform).
-- 3. Allows creating files, folders, renaming, deleting, and navigating.
-- 4. Key 'o' or '<C-o>' opens folders as Active Project (CWD).
-- ============================================================================

local M = {}

-- Get Desktop path cross-platform (Windows / macOS / Linux)
function M.get_desktop_path()
	local home = vim.fn.expand("~")
	local desktop = home .. "/Desktop"
	if vim.fn.isdirectory(desktop) == 1 then
		return desktop
	end

	-- Support for OneDrive Desktop on Windows
	local onedrive_desktop = home .. "/OneDrive/Desktop"
	if vim.fn.isdirectory(onedrive_desktop) == 1 then
		return onedrive_desktop
	end

	return home
end

-- Open native file explorer in Telescope
function M.open_desktop_explorer(opts)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	opts = opts or {}
	local curr_dir = opts.path or M.get_desktop_path()
	curr_dir = vim.fn.fnamemodify(curr_dir, ":p"):gsub("[/\\]$", "")

	if vim.fn.isdirectory(curr_dir) == 0 then
		curr_dir = M.get_desktop_path()
	end

	-- Scan items using Neovim native API (fs_scandir)
	local entries = {}
	local handle = vim.uv.fs_scandir(curr_dir)
	if handle then
		while true do
			local name, type = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local full_path = curr_dir .. "/" .. name
			local is_dir = (type == "directory")
			table.insert(entries, {
				name = name,
				path = full_path,
				is_dir = is_dir,
				display = (is_dir and "📁 " or "📄 ") .. name,
			})
		end
	end

	-- Sort: Directories first, then files alphabetically
	table.sort(entries, function(a, b)
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name:lower() < b.name:lower()
	end)

	pickers.new({
		prompt_title = " 📁 Explorer: " .. curr_dir .. " ",
		results_title = " Files / Folders | Press [?] for help ",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				return {
					value = entry,
					display = entry.display,
					ordinal = (entry.is_dir and "0_" or "1_") .. entry.name,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		layout_strategy = "horizontal",
		layout_config = {
			width = 0.85,
			height = 0.80,
			prompt_position = "top",
		},
		attach_mappings = function(prompt_bufnr, map)
			-- Enter: Enter folder or open file in editor
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				if item.is_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = item.path })
					end)
				else
					actions.close(prompt_bufnr)
					vim.cmd("edit " .. vim.fn.fnameescape(item.path))
				end
			end)

			-- Keys 'o', 'O' and '<C-o>': Set folder as Active Project (CWD)
			local set_project_cwd = function()
				local selection = action_state.get_selected_entry()
				local target = curr_dir
				if selection and selection.value and selection.value.is_dir then
					target = selection.value.path
				end
				actions.close(prompt_bufnr)

				-- Close Neo-tree & all splits to start completely clean
				pcall(vim.cmd, "Neotree close")
				pcall(vim.cmd, "only")

				-- Create a clean empty buffer
				vim.cmd("enew")
				local new_buf = vim.api.nvim_get_current_buf()

				-- Delete ALL old buffers from the previous project
				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if b ~= new_buf and vim.api.nvim_buf_is_valid(b) then
						pcall(vim.api.nvim_buf_delete, b, { force = true })
					end
				end

				pcall(vim.api.nvim_set_current_dir, target)

				local history_ok, history = pcall(require, "project_nvim.utils.history")
				if history_ok and history.recent_projects then
					table.insert(history.recent_projects, target)
					pcall(history.write_projects_to_history)
				end

				pcall(vim.cmd, "Neotree show dir=" .. vim.fn.fnameescape(target))
				vim.notify("📁 Project root changed to:\n" .. target, vim.log.levels.INFO, { title = "Active Project" })
			end
			map("i", "<C-o>", set_project_cwd)
			map("n", "<C-o>", set_project_cwd)
			map("n", "o", set_project_cwd)
			map("n", "O", set_project_cwd)

			-- Key 'a': Create file (e.g. index.js) or folder (e.g. src/ with trailing slash)
			local create_item = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Create new (add '/' at end for folder): " }, function(name)
						if not name or name == "" then
							return
						end
						local full_path = curr_dir .. "/" .. name
						if name:sub(-1) == "/" or name:sub(-1) == "\\" then
							vim.fn.mkdir(full_path, "p")
							vim.notify("📁 Folder created: " .. name, vim.log.levels.INFO)
						else
							local f = io.open(full_path, "w")
							if f then
								f:close()
								vim.notify("📄 File created: " .. name, vim.log.levels.INFO)
							end
						end
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "a", create_item)
			map("i", "<C-a>", create_item)

			-- Key 'r': Rename
			local rename_item = function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Rename to: ", default = item.name }, function(new_name)
						if not new_name or new_name == "" or new_name == item.name then
							return
						end
						local new_path = curr_dir .. "/" .. new_name
						os.rename(item.path, new_path)
						vim.notify("✏️ Renamed to: " .. new_name, vim.log.levels.INFO)
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "r", rename_item)

			-- Key 'd': Delete
			local delete_item = function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Delete '" .. item.name .. "'? (y/n): " }, function(confirm)
						if confirm and confirm:lower() == "y" then
							vim.fn.delete(item.path, "rf")
							vim.notify("🗑️ Deleted: " .. item.name, vim.log.levels.INFO)
						end
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "d", delete_item)

			-- Keys 'h' and '<BS>': Navigate to parent directory
			local go_parent = function()
				local parent = vim.fn.fnamemodify(curr_dir, ":h")
				if parent and parent ~= curr_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = parent })
					end)
				end
			end
			map("n", "h", go_parent)
			map("n", "<BS>", go_parent)

			-- Key 'l': Enter folder
			local drill_in = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value and selection.value.is_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = selection.value.path })
					end)
				end
			end
			map("n", "l", drill_in)

			-- Keys '?' and '<F1>': Minimalist context help
			local show_help = function()
				require("config.krs.context_help").show_help()
			end
			map("n", "?", show_help)
			map("n", "<F1>", show_help)

			return true
		end,
	}):find()
end

-- Open native file explorer rooted at a WSL distro's filesystem (Windows only)
function M.open_wsl_explorer()
	local wsl = require("config.krs.wsl")
	if not wsl.available() then
		vim.notify("WSL is not available on this system", vim.log.levels.WARN, { title = "WSL Explorer" })
		return
	end

	local distros = wsl.list_distros()
	if #distros == 0 then
		vim.notify("No WSL distributions found", vim.log.levels.WARN, { title = "WSL Explorer" })
		return
	end

	local function open_distro(distro)
		local root = wsl.distro_root(distro)
		if vim.fn.isdirectory(root) == 0 then
			vim.notify("Could not reach WSL distro filesystem: " .. root, vim.log.levels.ERROR, { title = "WSL Explorer" })
			return
		end
		M.open_desktop_explorer({ path = root })
	end

	if #distros == 1 then
		open_distro(distros[1])
	else
		vim.ui.select(distros, { prompt = "Select WSL distro:" }, function(choice)
			if choice then
				open_distro(choice)
			end
		end)
	end
end

-- Register global user commands
function M.setup()
	if vim.fn.exists(":TelescopeFileBrowserDesktop") == 0 then
		vim.api.nvim_create_user_command("TelescopeFileBrowserDesktop", function()
			M.open_desktop_explorer()
		end, { desc = "Open Floating File Explorer (Desktop)" })
	end

	if vim.fn.exists(":TelescopeFileBrowserWSL") == 0 then
		vim.api.nvim_create_user_command("TelescopeFileBrowserWSL", function()
			M.open_wsl_explorer()
		end, { desc = "Open Floating File Explorer (WSL)" })
	end
end

return M

