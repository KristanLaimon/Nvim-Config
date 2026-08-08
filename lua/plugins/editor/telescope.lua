return {
	'nvim-telescope/telescope.nvim',
	dependencies = { 'nvim-lua/plenary.nvim', 'ahmedkhalf/project.nvim' },
	config = function()
		local builtin = require('telescope.builtin')
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local conf = require('telescope.config').values
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')
		local themes = require('telescope.themes')

		vim.keymap.set('n', '<C-k>', builtin.find_files, { desc = 'Telescope find files' })
		vim.keymap.set('i', '<C-k>', builtin.find_files, { desc = 'Telescope find files' })
		vim.keymap.set('n', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })
		vim.keymap.set('i', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })
		vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

		local function open_folder_picker(opts)
			opts = opts or {}
			local desktop_path = vim.fn.expand('~/Desktop')
			if vim.fn.isdirectory(desktop_path) == 0 then
				desktop_path = vim.fn.expand('~')
			end

			local curr_dir = opts.cwd or desktop_path
			curr_dir = vim.fn.fnamemodify(curr_dir, ':p'):gsub('[/\\]$', '')

			local dirs = { curr_dir }

			if vim.fn.executable('fd') == 1 then
				local cmd = { 'fd', '.', curr_dir, '--type', 'd', '--hidden', '--exclude', '.git', '--exclude', 'node_modules', '--exclude', '.cache', '--max-depth', '3' }
				local output = vim.fn.systemlist(cmd)
				if vim.v.shell_error == 0 then
					for _, line in ipairs(output) do
						if line ~= '' then
							local full = line:gsub('\\', '/'):gsub('/$', '')
							table.insert(dirs, full)
						end
					end
				end
			else
				local scan_ok, scandir = pcall(require, 'plenary.scandir')
				if scan_ok then
					local results = scandir.scan_dir(curr_dir, {
						only_dirs = true,
						depth = 3,
						hidden = false,
					})
					for _, d in ipairs(results) do
						table.insert(dirs, (d:gsub('\\', '/'):gsub('/$', '')))
					end
				end
			end

			local function add_to_recent_projects(dir_path)
				dir_path = vim.fn.fnamemodify(dir_path, ':p'):gsub('[/\\]$', '')
				local history_ok, history = pcall(require, 'project_nvim.utils.history')
				if history_ok then
					local projects = history.get_recent_projects()
					local new_projects = { dir_path }
					for _, p in ipairs(projects) do
						local norm_p = vim.fn.fnamemodify(p, ':p'):gsub('[/\\]$', '')
						if norm_p:lower() ~= dir_path:lower() then
							table.insert(new_projects, p)
						end
					end
					history.write_projects_to_history(new_projects)
				end
			end

			local function open_directory(dir_path)
				dir_path = vim.fn.fnamemodify(dir_path, ':p'):gsub('[/\\]$', '')
				if vim.fn.isdirectory(dir_path) == 0 then
					vim.notify('Directory does not exist: ' .. dir_path, vim.log.levels.ERROR)
					return
				end

				pcall(vim.api.nvim_set_current_dir, dir_path)
				add_to_recent_projects(dir_path)

				local curr_buf = vim.api.nvim_get_current_buf()
				local is_alpha = vim.bo[curr_buf].filetype == 'alpha'

				-- Close any remaining Alpha dashboard buffers
				for _, b in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == 'alpha' then
						pcall(vim.api.nvim_buf_delete, b, { force = true })
					end
				end

				if is_alpha then
					vim.cmd('enew')
				end

				pcall(vim.cmd, 'Neotree show dir=' .. vim.fn.fnameescape(dir_path))
				vim.notify('📁 Opened folder: ' .. dir_path, vim.log.levels.INFO)
			end

			pickers.new(themes.get_dropdown({
				prompt_title = ' 📁 Open Folder (Root: ' .. vim.fn.fnamemodify(curr_dir, ':t') .. ') ',
				finder = finders.new_table({
					results = dirs,
					entry_maker = function(entry)
						local norm_entry = entry:gsub('\\', '/'):gsub('/$', '')
						local norm_curr = curr_dir:gsub('\\', '/'):gsub('/$', '')
						local rel = norm_entry

						if norm_entry:lower() == norm_curr:lower() then
							rel = '. (Current Root: ' .. norm_entry .. ')'
						elseif norm_entry:lower():sub(1, #norm_curr) == norm_curr:lower() then
							rel = norm_entry:sub(#norm_curr + 2)
						end

						return {
							value = norm_entry,
							display = '📁 ' .. rel,
							ordinal = rel .. ' ' .. norm_entry,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection and selection.value then
							open_directory(selection.value)
						end
					end)

					local drill_down = function()
						local selection = action_state.get_selected_entry()
						if selection and selection.value and vim.fn.isdirectory(selection.value) == 1 then
							actions.close(prompt_bufnr)
							vim.schedule(function()
								open_folder_picker({ cwd = selection.value })
							end)
						end
					end
					map('i', '<C-l>', drill_down)
					map('n', '<C-l>', drill_down)

					local go_up = function()
						local parent = vim.fn.fnamemodify(curr_dir, ':h')
						if parent and parent ~= curr_dir then
							actions.close(prompt_bufnr)
							vim.schedule(function()
								open_folder_picker({ cwd = parent })
							end)
						end
					end
					map('i', '<C-h>', go_up)
					map('n', '<C-h>', go_up)

					return true
				end,
			}), {}):find()
		end

		vim.keymap.set('n', '<C-o>', open_folder_picker, { desc = 'Telescope open folder' })
		vim.keymap.set('i', '<C-o>', open_folder_picker, { desc = 'Telescope open folder' })
	end
}
