return {
	'nvim-telescope/telescope.nvim',
	cmd = {
		'Telescope',
		'TelescopeOpenFolder',
		'TelescopeFileBrowserDesktop',
		'TelescopeFindFilesSplitLeft',
		'TelescopeFindFilesSplitBelow',
		'TelescopeFindFilesSplitAbove',
		'TelescopeFindFilesSplitRight',
		'TelescopeFindFilesNoIgnore',
	},
	keys = {
		{ '<C-k>', '<cmd>Telescope find_files<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (excludes .gitignore)' },
		{ '<C-A-k>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<C-A-K>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<C-M-k>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<C-M-K>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<A-C-k>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<A-C-K>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<M-C-k>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<M-C-K>', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'i' }, desc = 'Telescope find files (ignoring .gitignore)' },
		{ '<leader>fa', '<cmd>TelescopeFindFilesNoIgnore<CR>', mode = { 'n', 'v' }, desc = 'Find all files (no .gitignore)' },
		{ '<C-f>', '<cmd>Telescope live_grep<CR>', mode = { 'n', 'i' }, desc = 'Telescope live grep' },
		{ '<leader>fh', '<cmd>Telescope help_tags<CR>', desc = 'Telescope help tags' },
		{ '<C-S-o>', '<cmd>TelescopeOpenFolder<CR>', mode = { 'n', 'i' }, desc = 'Telescope open folder' },
		{ '<C-S-f>', '<cmd>TelescopeFileBrowserDesktop<CR>', mode = { 'n', 'i', 'v' }, desc = 'Open Desktop File Explorer' },
		{ '<C-S-h>', '<cmd>TelescopeFindFilesSplitLeft<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split left' },
		{ '<C-S-j>', '<cmd>TelescopeFindFilesSplitBelow<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split below' },
		{ '<C-S-k>', '<cmd>TelescopeFindFilesSplitAbove<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split above' },
		{ '<C-S-l>', '<cmd>TelescopeFindFilesSplitRight<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split right' },
		{ '<C-S-H>', '<cmd>TelescopeFindFilesSplitLeft<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split left' },
		{ '<C-S-J>', '<cmd>TelescopeFindFilesSplitBelow<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split below' },
		{ '<C-S-K>', '<cmd>TelescopeFindFilesSplitAbove<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split above' },
		{ '<C-S-L>', '<cmd>TelescopeFindFilesSplitRight<CR>', mode = { 'n', 'i', 'v' }, desc = 'Telescope find files split right' },
	},
	dependencies = {
		'nvim-lua/plenary.nvim',
		'ahmedkhalf/project.nvim',
		'nvim-telescope/telescope-file-browser.nvim',
	},
	config = function()

		local telescope = require('telescope')
		local builtin = require('telescope.builtin')
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local conf = require('telescope.config').values
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')
		local themes = require('telescope.themes')

		telescope.setup({
			defaults = {
				mappings = {
					n = {
						["?"] = function()
							require("config.krs.context_help").show_help()
						end,
					},
				},
			},
		})

		local function find_files_gitignore()
			local is_git = false
			local cwd = vim.fn.getcwd()
			if vim.fn.isdirectory(cwd .. "/.git") == 1 then
				is_git = true
			else
				local out = vim.fn.system("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --is-inside-work-tree 2>NUL")
				if out and out:match("true") then
					is_git = true
				end
			end

			if is_git then
				local ok = pcall(builtin.git_files, { show_untracked = true })
				if not ok then
					builtin.find_files({ no_ignore = false, hidden = false })
				end
			elseif vim.fn.executable("rg") == 1 then
				builtin.find_files({
					find_command = { "rg", "--files", "--color=never", "--glob", "!.git/*" },
				})
			elseif vim.fn.executable("fd") == 1 then
				builtin.find_files({
					find_command = { "fd", "--type", "f", "--exclude", ".git" },
				})
			else
				builtin.find_files({ no_ignore = false, hidden = false })
			end
		end

		local function find_files_no_ignore()
			if vim.fn.executable("rg") == 1 then
				builtin.find_files({
					find_command = { "rg", "--files", "--color=never", "--no-ignore", "--hidden", "--glob", "!.git/*" },
				})
			elseif vim.fn.executable("fd") == 1 then
				builtin.find_files({
					find_command = { "fd", "--type", "f", "--no-ignore", "--hidden", "--exclude", ".git" },
				})
			else
				builtin.find_files({ no_ignore = true, hidden = true })
			end
		end

		_G.FindFilesGitignore = find_files_gitignore
		_G.FindFilesNoIgnore = find_files_no_ignore

		vim.api.nvim_create_user_command('TelescopeFindFilesNoIgnore', find_files_no_ignore, { desc = 'Find files ignoring .gitignore' })

		local gitignore_keys = { '<C-k>', '<C-/>', '<C-_>' }
		for _, key in ipairs(gitignore_keys) do
			vim.keymap.set({ 'n', 'i' }, key, find_files_gitignore, { noremap = true, silent = true, desc = 'Telescope find files (excludes .gitignore)' })
		end

		local no_ignore_keys = { '<C-A-k>', '<C-A-K>', '<C-M-k>', '<C-M-K>', '<A-C-k>', '<A-C-K>', '<M-C-k>', '<M-C-K>', '<C-S-/>', '<C-?>', '<leader>fa' }
		for _, key in ipairs(no_ignore_keys) do
			vim.keymap.set({ 'n', 'i' }, key, find_files_no_ignore, { noremap = true, silent = true, desc = 'Telescope find files (ignoring .gitignore)' })
		end



		vim.keymap.set('n', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })
		vim.keymap.set('i', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })
		vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

		local function normalize_dir_path(path)
			if not path or path == '' then
				return ''
			end
			local p = vim.fn.fnamemodify(path, ':p')
			if p:match('^[A-Za-z]:[/\\]$') or p == '/' then
				return p
			end
			return (p:gsub('[/\\]$', ''))
		end

		local function open_folder_picker(opts)
			opts = opts or {}
			local desktop_path = vim.fn.expand('~/Desktop')
			if vim.fn.isdirectory(desktop_path) == 0 then
				desktop_path = vim.fn.expand('~')
			end

			local curr_dir = opts.cwd or desktop_path
			curr_dir = normalize_dir_path(curr_dir)

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
				local norm_path = normalize_dir_path(dir_path):gsub('\\', '/')
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

				pcall(function()
					require('config.krs.wsl').add_recent_project(norm_path)
				end)
			end

			local function open_directory(dir_path)
				dir_path = normalize_dir_path(dir_path)
				if vim.fn.isdirectory(dir_path) == 0 then
					vim.notify('Directory does not exist: ' .. dir_path, vim.log.levels.ERROR)
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
				add_to_recent_projects(dir_path)
				if _G.AddOpenedFolder then
					_G.AddOpenedFolder(dir_path)
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

		pcall(telescope.load_extension, 'file_browser')

		vim.api.nvim_create_user_command('TelescopeOpenFolder', function()
			open_folder_picker()
		end, {})
		vim.keymap.set({ 'n', 'i' }, '<C-S-o>', open_folder_picker, { desc = 'Telescope open folder' })

		vim.api.nvim_create_user_command('TelescopeFileBrowserDesktop', function()
			require('config.krs.file_explorer').open_desktop_explorer()
		end, {})
		vim.keymap.set({ 'n', 'i' }, '<C-S-f>', function()
			require('config.krs.file_explorer').open_desktop_explorer()
		end, { desc = 'Open Desktop File Explorer' })

		local function open_find_files_split(direction)
			local dir_names = {
				h = 'Left (←)',
				j = 'Down (↓)',
				k = 'Up (↑)',
				l = 'Right (→)',
			}

			builtin.find_files({
				prompt_title = ' 🔍 Find & Open File ' .. (dir_names[direction] or direction) .. ' ',
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection and (selection.value or selection[1]) then
							local filepath = selection.value or selection[1]
							local cmd
							if direction == 'h' then
								cmd = 'leftabove vsplit '
							elseif direction == 'l' then
								cmd = 'rightbelow vsplit '
							elseif direction == 'k' then
								cmd = 'leftabove split '
							elseif direction == 'j' then
								cmd = 'rightbelow split '
							end
							if cmd then
								vim.cmd(cmd .. vim.fn.fnameescape(filepath))
							end
						end
					end)
					return true
				end,
			})
		end

		vim.api.nvim_create_user_command('TelescopeFindFilesSplitLeft', function() open_find_files_split('h') end, {})
		vim.api.nvim_create_user_command('TelescopeFindFilesSplitBelow', function() open_find_files_split('j') end, {})
		vim.api.nvim_create_user_command('TelescopeFindFilesSplitAbove', function() open_find_files_split('k') end, {})
		vim.api.nvim_create_user_command('TelescopeFindFilesSplitRight', function() open_find_files_split('l') end, {})

		local split_key_modes = { 'n', 'i', 'v' }
		local split_keymaps = {
			h = { '<C-S-h>', '<C-S-H>' },
			j = { '<C-S-j>', '<C-S-J>' },
			k = { '<C-S-k>', '<C-S-K>' },
			l = { '<C-S-l>', '<C-S-L>' },
		}

		for dir, keys_list in pairs(split_keymaps) do
			for _, k in ipairs(keys_list) do
				vim.keymap.set(split_key_modes, k, function()
					open_find_files_split(dir)
				end, { noremap = true, silent = true, desc = 'Find file and open in split (' .. dir .. ')' })
			end
		end
	end,
}

