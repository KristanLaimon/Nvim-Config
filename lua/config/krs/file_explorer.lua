-- ============================================================================
-- 🦊 KRS CONFIG: Native Floating File Explorer (Pure Lua Telescope)
-- ============================================================================
-- 1. 100% Native in Lua without external binaries (avoids 'Executable not found' errors).
-- 2. Defaults to user's Desktop directory (Cross-platform).
-- 3. Allows creating files, folders, renaming, deleting, and navigating.
-- 4. Key 'o' or '<C-o>' opens folders as Active Project (CWD).
-- ============================================================================

local M = {}

local favorites_file = vim.fn.stdpath("data") .. "/project_favorites.json"

local function load_favorites()
	local f = io.open(favorites_file, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

local function save_favorites(favs)
	local ok, encoded = pcall(vim.json.encode, favs)
	if ok then
		local f = io.open(favorites_file, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

local function normalize_path(p)
	if not p or p == "" then
		return ""
	end
	local clean = p:gsub("\\", "/"):gsub("/$", "")
	if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
		clean = clean:sub(1, 1):lower() .. clean:sub(2)
	end
	return clean
end

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

	local favs = load_favorites()

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
			local norm_path = normalize_path(full_path)
			local is_dir = (type == "directory")
			local is_fav = favs[norm_path] == true
			local icon = is_dir and "📁 " or "📄 "
			local fav_mark = is_fav and "⭐ " or ""

			table.insert(entries, {
				name = name,
				path = full_path,
				norm = norm_path,
				is_dir = is_dir,
				is_favorite = is_fav,
				display = fav_mark .. icon .. name,
			})
		end
	end

	-- Sort: Favorites first, then Directories, then files alphabetically
	table.sort(entries, function(a, b)
		if a.is_favorite ~= b.is_favorite then
			return a.is_favorite
		end
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name:lower() < b.name:lower()
	end)

	pickers.new({
		prompt_title = " 📁 Explorer: " .. curr_dir .. " ",
		results_title = " Files / Folders | [Ctrl+F]=Favorite | Press [?] for help ",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				local fav_prefix = entry.is_favorite and "0_" or "1_"
				local dir_prefix = entry.is_dir and "0_" or "1_"
				return {
					value = entry,
					display = entry.display,
					ordinal = fav_prefix .. dir_prefix .. entry.name,
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
				pcall(function()
					require("config.krs.wsl").add_recent_project(target)
				end)

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

			-- Key '<C-f>': Toggle Favorite (folder or file)
			local toggle_favorite = function()
				local selection = action_state.get_selected_entry()
				local target_path = nil
				local target_name = nil

				if selection and selection.value then
					target_path = selection.value.path
					target_name = selection.value.name
				else
					target_path = curr_dir
					target_name = vim.fn.fnamemodify(curr_dir, ":t")
				end

				if not target_path or target_path == "" then
					return
				end

				local norm = normalize_path(target_path)
				local current_favs = load_favorites()

				if current_favs[norm] then
					current_favs[norm] = nil
					vim.notify("Removed from favorites: " .. target_name, vim.log.levels.INFO, { title = "Explorer Favorites" })
				else
					current_favs[norm] = true
					if vim.fn.isdirectory(target_path) == 1 then
						local history_ok, history = pcall(require, "project_nvim.utils.history")
						if history_ok and history.recent_projects then
							local exists = false
							for _, p in ipairs(history.recent_projects) do
								if normalize_path(p) == norm then
									exists = true
									break
								end
							end
							if not exists then
								table.insert(history.recent_projects, target_path)
								pcall(history.write_projects_to_history)
							end
						end
					end
					vim.notify("⭐ Saved as favorite: " .. target_name, vim.log.levels.INFO, { title = "Explorer Favorites" })
				end

				save_favorites(current_favs)

				actions.close(prompt_bufnr)
				vim.schedule(function()
					M.open_desktop_explorer({ path = curr_dir })
				end)
			end
			map("i", "<C-f>", toggle_favorite)
			map("n", "<C-f>", toggle_favorite)

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

