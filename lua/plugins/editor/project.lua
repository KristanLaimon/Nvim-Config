return {
	'ahmedkhalf/project.nvim',
	event = 'VeryLazy',
	keys = {
		{ '<C-S-r>', '<cmd>Telescope projects<CR>', desc = 'Telescope recent projects' },
	},
	dependencies = {
		'nvim-telescope/telescope.nvim',
		'nvim-tree/nvim-web-devicons',
	},
	config = function()
		local project_nvim = require('project_nvim')
		local telescope = require('telescope')

		project_nvim.setup({
			manual_mode = true,
			manual_gc = false,
			detection_methods = { 'pattern', 'lsp' },
			patterns = {
				'.git',
				'_darcs',
				'.hg',
				'.bzr',
				'.svn',
				'Makefile',
				'package.json',
				'go.mod',
				'Cargo.toml',
				'pyproject.toml',
				'tsconfig.json',
				'pom.xml',
				'build.gradle',
			},
			silent_chdir = true,
			scope_chdir = 'global',
		})
		telescope.load_extension('projects')

		local favorites_file = vim.fn.stdpath('data') .. '/project_favorites.json'

		local function load_favorites()
			local f = io.open(favorites_file, 'r')
			if not f then
				return {}
			end
			local content = f:read('*a')
			f:close()
			local ok, data = pcall(vim.json.decode, content)
			if ok and type(data) == 'table' then
				return data
			end
			return {}
		end

		local function save_favorites(favs)
			local ok, encoded = pcall(vim.json.encode, favs)
			if ok then
				local f = io.open(favorites_file, 'w')
				if f then
					f:write(encoded)
					f:close()
				end
			end
		end

		local function normalize_proj_path(p)
			if not p or p == '' then
				return ''
			end
			local clean = p:gsub('\\', '/'):gsub('/$', '')
			if vim.fn.has('win32') == 1 or vim.fn.has('wsl') == 1 then
				clean = clean:sub(1, 1):lower() .. clean:sub(2)
			end
			return clean
		end

		local function save_history_to_disk(list)
			local path_ok, path = pcall(require, 'project_nvim.utils.path')
			if not path_ok then
				return
			end

			local file = io.open(path.historyfile, 'w')
			if file then
				local seen = {}
				for _, p in ipairs(list) do
					if type(p) == 'string' then
						local clean_p = normalize_proj_path(p)
						if clean_p ~= '' and clean_p ~= 'c:' and clean_p ~= 'c:/' and not seen[clean_p:lower()] then
							seen[clean_p:lower()] = true
							file:write(clean_p .. '\n')
						end
					end
				end
				file:close()
			end
		end

		local function get_project_icon(dir)
			local devicons_ok, devicons = pcall(require, 'nvim-web-devicons')

			if vim.fn.filereadable(dir .. '/Cargo.toml') == 1 then
				return (devicons_ok and devicons.get_icon('Cargo.toml') or '🦀'), 'DevIconRs'
			elseif vim.fn.filereadable(dir .. '/package.json') == 1 then
				return (devicons_ok and devicons.get_icon('package.json') or ''), 'DevIconJson'
			elseif
				vim.fn.filereadable(dir .. '/pyproject.toml') == 1
				or vim.fn.filereadable(dir .. '/requirements.txt') == 1
				or vim.fn.filereadable(dir .. '/setup.py') == 1
			then
				return (devicons_ok and devicons.get_icon('a.py') or ''), 'DevIconPy'
			elseif vim.fn.filereadable(dir .. '/go.mod') == 1 then
				return (devicons_ok and devicons.get_icon('go.mod') or ''), 'DevIconGo'
			elseif
				vim.fn.filereadable(dir .. '/pom.xml') == 1
				or vim.fn.filereadable(dir .. '/build.gradle') == 1
				or vim.fn.filereadable(dir .. '/build.gradle.kts') == 1
			then
				return (devicons_ok and devicons.get_icon('a.java') or ''), 'DevIconJava'
			elseif vim.fn.filereadable(dir .. '/CMakeLists.txt') == 1 or vim.fn.filereadable(dir .. '/Makefile') == 1 then
				return (devicons_ok and devicons.get_icon('CMakeLists.txt') or ''), 'DevIconC'
			elseif vim.fn.filereadable(dir .. '/init.lua') == 1 or vim.fn.isdirectory(dir .. '/lua') == 1 then
				return (devicons_ok and devicons.get_icon('init.lua') or ''), 'DevIconLua'
			elseif vim.fn.filereadable(dir .. '/composer.json') == 1 then
				return (devicons_ok and devicons.get_icon('composer.json') or '🐘'), 'DevIconPhp'
			end

			-- Default: Blank page symbol as requested
			return '📄', 'Directory'
		end

		local function open_projects_picker(opts)
			opts = opts or {}
			local history = require('project_nvim.utils.history')
			local tstate = require('telescope.actions.state')
			local actions = require('telescope.actions')
			local pickers = require('telescope.pickers')
			local finders = require('telescope.finders')
			local conf = require('telescope.config').values
			local themes = require('telescope.themes')

			local raw_projects = {}
			local seen_raw = {}
			local wsl_ok, wsl = pcall(require, 'plugins.krs.wsl')

			-- 1. Gather WSL recent projects (fast, load_recent_raw without disk stat)
			if wsl_ok and wsl.get_recent_projects then
				for _, wp in ipairs(wsl.get_recent_projects(false)) do
					local norm = normalize_proj_path(wp)
					if norm ~= '' and not seen_raw[norm:lower()] then
						seen_raw[norm:lower()] = true
						table.insert(raw_projects, wp)
					end
				end
			end

			-- 2. Gather standard history projects
			local proj_history = history.get_recent_projects() or {}
			for _, p in ipairs(proj_history) do
				local norm = normalize_proj_path(p)
				if norm ~= '' and not seen_raw[norm:lower()] then
					seen_raw[norm:lower()] = true
					table.insert(raw_projects, p)
				end
			end

			local favs = load_favorites()

			local non_fav_items = {}
			local fav_items = {}

			for _, p in ipairs(raw_projects) do
				local norm = normalize_proj_path(p)
				local is_wsl = (wsl_ok and wsl.is_wsl_path and wsl.is_wsl_path(p)) or p:gsub('\\', '/'):match('^//wsl') ~= nil

				local is_valid = false
				local icon, hl

				if is_wsl then
					-- WSL path: DO NOT call vim.fn.isdirectory() or get_project_icon().
					-- Statting WSL UNC paths over SMB forces Windows to initialize/boot WSL,
					-- causing UI lag. We skip disk stat when showing recent projects list.
					is_valid = true
					icon = '🐧'
					hl = 'Directory'
				else
					-- Local Windows path: fast filesystem check
					if vim.fn.isdirectory(p) == 1 then
						is_valid = true
						icon, hl = get_project_icon(p)
					end
				end

				if is_valid then
					local is_fav = favs[norm] == true
					local entry_item = {
						path = p,
						norm = norm,
						is_favorite = is_fav,
						is_wsl = is_wsl,
						icon = icon,
						hl = hl,
					}
					if is_fav then
						table.insert(fav_items, entry_item)
					else
						table.insert(non_fav_items, entry_item)
					end
				end
			end

			-- Favorites first (at the top), non-favorites below
			local sorted_entries = {}
			for _, item in ipairs(fav_items) do
				table.insert(sorted_entries, item)
			end
			for _, item in ipairs(non_fav_items) do
				table.insert(sorted_entries, item)
			end

			local function open_project(dir_path)
				if not dir_path or dir_path == '' then
					return
				end

				local is_wsl = (wsl_ok and wsl.is_wsl_path and wsl.is_wsl_path(dir_path)) or dir_path:gsub('\\', '/'):match('^//wsl') ~= nil

				-- Now that the user explicitly clicked/selected this project, check directory existence.
				-- For WSL paths, this will access WSL now (which is intended since the user clicked it).
				if vim.fn.isdirectory(dir_path) == 0 then
					if is_wsl then
						vim.notify('🐧 WSL project directory is unreachable or does not exist:\n' .. tostring(dir_path), vim.log.levels.ERROR, { title = 'Recent Projects' })
					else
						vim.notify('Directory does not exist: ' .. tostring(dir_path), vim.log.levels.ERROR)
					end
					return
				end

				-- Close Neo-tree & all splits to start completely clean
				pcall(vim.cmd, 'Neotree close')
				pcall(vim.cmd, 'only')

				-- Create a clean empty buffer
				vim.cmd('enew')
				local new_buf = vim.api.nvim_get_current_buf()

				-- Delete ALL old buffers from the previous project
				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if b ~= new_buf and vim.api.nvim_buf_is_valid(b) then
						pcall(vim.api.nvim_buf_delete, b, { force = true })
					end
				end

				pcall(vim.api.nvim_set_current_dir, dir_path)

				-- Add to recent projects
				if wsl_ok and wsl.add_recent_project and is_wsl then
					wsl.add_recent_project(dir_path)
				end

				local norm_path = normalize_proj_path(dir_path)
				if history.recent_projects then
					local new_recent = {}
					for _, p in ipairs(history.recent_projects) do
						if normalize_proj_path(p):lower() ~= norm_path:lower() then
							table.insert(new_recent, p)
						end
					end
					table.insert(new_recent, dir_path)
					history.recent_projects = new_recent
					save_history_to_disk(history.recent_projects)
				end

				if _G.AddOpenedFolder then
					_G.AddOpenedFolder(dir_path)
				end

				pcall(vim.cmd, 'Neotree show dir=' .. vim.fn.fnameescape(dir_path))
				vim.notify('📁 Switched to project: ' .. dir_path, vim.log.levels.INFO)
			end

			pickers.new(themes.get_dropdown({
				prompt_title = ' 📁 Recent Projects | [f] Favorite | [r] Rename | [d] Delete ',
				width = 0.85,
				layout_config = {
					width = 0.85,
					height = 0.70,
				},
				finder = finders.new_table({
					results = sorted_entries,
					entry_maker = function(entry)
						local fav_mark = entry.is_favorite and ' ⭐ [Favorite]' or ''
						local title = entry.icon .. '  ' .. entry.path .. fav_mark
						return {
							value = entry,
							display = title,
							ordinal = (entry.is_favorite and '0_' or '1_') .. entry.path,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						local selection = tstate.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection and selection.value and selection.value.path then
							open_project(selection.value.path)
						end
					end)

					-- f: Toggle Favorite (Saves to favorites & keeps at top)
					local function toggle_favorite()
						local selection = tstate.get_selected_entry()
						if not selection or not selection.value then
							return
						end

						local item = selection.value
						local norm = item.norm
						local current_favs = load_favorites()

						if current_favs[norm] then
							current_favs[norm] = nil
							vim.notify('Removed project from favorites', vim.log.levels.INFO, { title = 'Recent Projects' })
						else
							current_favs[norm] = true
							vim.notify('⭐ Project saved as favorite (top first)', vim.log.levels.INFO, { title = 'Recent Projects' })
						end

						save_favorites(current_favs)
						actions.close(prompt_bufnr)
						vim.schedule(function()
							open_projects_picker(opts)
						end)
					end

					-- r: Rename Project
					local function rename_project()
						local selection = tstate.get_selected_entry()
						if not selection or not selection.value then
							return
						end
						local old_path = selection.value.path
						local old_norm = selection.value.norm
						local old_name = vim.fn.fnamemodify(old_path, ':t')

						actions.close(prompt_bufnr)

						vim.schedule(function()
							local input_modal = require('plugins.krs.input_modal')
							input_modal.open({
								label = 'Rename Project (' .. old_name .. ')',
								default_value = old_name,
								relative = 'editor',
								callback = function(ok, new_name)
									if not ok or not new_name or new_name == '' or new_name == old_name then
										open_projects_picker(opts)
										return
									end

									local parent_dir = vim.fn.fnamemodify(old_path, ':h')
									local new_path = parent_dir .. '/' .. new_name

									local is_wsl = (wsl_ok and wsl.is_wsl_path and wsl.is_wsl_path(old_path))
									if not is_wsl and vim.fn.isdirectory(old_path) == 1 then
										local renamed, err = os.rename(old_path, new_path)
										if not renamed then
											vim.notify('Failed to rename directory: ' .. tostring(err), vim.log.levels.ERROR, { title = 'Recent Projects' })
											open_projects_picker(opts)
											return
										end
									end

									-- Update history
									if history.recent_projects then
										local new_recent = {}
										for _, p in ipairs(history.recent_projects) do
											if normalize_proj_path(p) == old_norm then
												table.insert(new_recent, new_path)
											else
												table.insert(new_recent, p)
											end
										end
										history.recent_projects = new_recent
										save_history_to_disk(history.recent_projects)
									end

									-- Update WSL recent
									if is_wsl and wsl_ok then
										wsl.remove_recent_project(old_path)
										wsl.add_recent_project(new_path)
									end

									-- Update favorites
									local current_favs = load_favorites()
									if current_favs[old_norm] then
										current_favs[old_norm] = nil
										current_favs[normalize_proj_path(new_path)] = true
										save_favorites(current_favs)
									end

									vim.notify('✏️ Project renamed to: ' .. new_name, vim.log.levels.INFO, { title = 'Recent Projects' })
									open_projects_picker(opts)
								end,
							})
						end)
					end

					-- d: Delete Project from Recent Projects List
					local function delete_project()
						local selection = tstate.get_selected_entry()
						if selection == nil or not selection.value then
							return
						end

						local target_val = selection.value.norm
						local choice = vim.fn.confirm("Delete '" .. selection.value.path .. "' from project list?", "&Yes\n&No", 2)
						if choice ~= 1 then
							return
						end

						if history.recent_projects then
							local new_recent = {}
							for _, p in ipairs(history.recent_projects) do
								if normalize_proj_path(p) ~= target_val then
									table.insert(new_recent, p)
								end
							end
							history.recent_projects = new_recent
						end

						if history.session_projects then
							local new_session = {}
							for _, p in ipairs(history.session_projects) do
								if normalize_proj_path(p) ~= target_val then
									table.insert(new_session, p)
								end
							end
							history.session_projects = new_session
						end

						save_history_to_disk(history.get_recent_projects())

						if wsl_ok then
							wsl.remove_recent_project(selection.value.path)
						end

						local current_favs = load_favorites()
						if current_favs[target_val] then
							current_favs[target_val] = nil
							save_favorites(current_favs)
						end

						actions.close(prompt_bufnr)
						vim.schedule(function()
							open_projects_picker(opts)
						end)
					end

					map('n', 'f', toggle_favorite)
					map('n', 'r', rename_project)
					map('n', 'd', delete_project)

					return true
				end,
			}), {}):find()
		end

		-- Override Telescope projects extension method to use our custom picker
		telescope.extensions.projects.projects = open_projects_picker

		vim.keymap.set('n', '<C-S-r>', function()
			open_projects_picker()
		end, { desc = 'Telescope recent projects' })
	end,
}

