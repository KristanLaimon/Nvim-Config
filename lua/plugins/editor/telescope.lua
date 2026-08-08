return {
	'nvim-telescope/telescope.nvim',
	cmd = 'Telescope',
	keys = {
		{ '<C-k>', '<cmd>Telescope find_files<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files' },
		{ '<C-f>', '<cmd>Telescope live_grep<CR>', mode = { 'n', 'i' }, desc = 'Telescope live grep' },
		{ '<leader>fh', '<cmd>Telescope help_tags<CR>', desc = 'Telescope help tags' },
		{ '<C-S-o>', '<cmd>TelescopeOpenFolder<CR>', mode = { 'n', 'i' }, desc = 'Telescope open folder' },
	},
	dependencies = { 'nvim-lua/plenary.nvim', 'ahmedkhalf/project.nvim' },
	config = function()

		local telescope = require('telescope')
		local builtin = require('telescope.builtin')
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local conf = require('telescope.config').values
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')
		local themes = require('telescope.themes')

		telescope.setup({})

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
				if not dir_path or dir_path == '' then
					return
				end
				local norm_path = vim.fn.fnamemodify(dir_path, ':p'):gsub('[/\\]$', ''):gsub('\\', '/')
				if vim.fn.has('win32') == 1 or vim.fn.has('wsl') == 1 then
					norm_path = norm_path:sub(1, 1):lower() .. norm_path:sub(2)
				end

				local history_ok, history = pcall(require, 'project_nvim.utils.history')
				if history_ok then
					history.session_projects = history.session_projects or {}
					local filtered_session = {}
					for _, p in ipairs(history.session_projects) do
						local p_norm = p:gsub('\\', '/'):gsub('/$', '')
						if vim.fn.has('win32') == 1 or vim.fn.has('wsl') == 1 then
							p_norm = p_norm:sub(1, 1):lower() .. p_norm:sub(2)
						end
						if p_norm:lower() ~= norm_path:lower() then
							table.insert(filtered_session, p)
						end
					end
					table.insert(filtered_session, norm_path)
					history.session_projects = filtered_session

					if history.recent_projects ~= nil then
						local filtered_recent = {}
						for _, p in ipairs(history.recent_projects) do
							local p_norm = p:gsub('\\', '/'):gsub('/$', '')
							if vim.fn.has('win32') == 1 or vim.fn.has('wsl') == 1 then
								p_norm = p_norm:sub(1, 1):lower() .. p_norm:sub(2)
							end
							if p_norm:lower() ~= norm_path:lower() then
								table.insert(filtered_recent, p)
							end
						end
						table.insert(filtered_recent, norm_path)
						history.recent_projects = filtered_recent
					end

					history.write_projects_to_history()
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
				if _G.AddOpenedFolder then
					_G.AddOpenedFolder(dir_path)
				end

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

		vim.api.nvim_create_user_command('TelescopeOpenFolder', function()
			open_folder_picker()
		end, {})
		vim.keymap.set({ 'n', 'i' }, '<C-S-o>', open_folder_picker, { desc = 'Telescope open folder' })
	end,
}
