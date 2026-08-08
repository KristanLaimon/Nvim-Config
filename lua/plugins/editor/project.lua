return {
	'ahmedkhalf/project.nvim',
	event = 'VeryLazy',
	keys = {
		{ '<C-S-r>', '<cmd>Telescope projects<CR>', desc = 'Telescope recent projects' },
	},
	dependencies = { 'nvim-telescope/telescope.nvim' },
	config = function()

		require('project_nvim').setup({
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
		require('telescope').load_extension('projects')

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
						local clean_p = p:gsub('\\', '/'):gsub('/$', '')
						if vim.fn.has('win32') == 1 or vim.fn.has('wsl') == 1 then
							clean_p = clean_p:sub(1, 1):lower() .. clean_p:sub(2)
						end
						if clean_p ~= '' and clean_p ~= 'c:' and clean_p ~= 'c:/' and not seen[clean_p:lower()] then
							seen[clean_p:lower()] = true
							file:write(clean_p .. '\n')
						end
					end
				end
				file:close()
			end
		end

		vim.keymap.set('n', '<C-S-r>', function()
			local history = require('project_nvim.utils.history')
			local tstate = require('telescope.actions.state')
			local actions = require('telescope.actions')

			local function delete_project(prompt_bufnr)
				local selected = tstate.get_selected_entry(prompt_bufnr)
				if selected == nil or not selected.value then
					return
				end

				local target_val = selected.value:gsub('\\', '/'):gsub('/$', ''):lower()
				local choice = vim.fn.confirm("Delete '" .. selected.value .. "' from project list?", "&Yes\n&No", 2)
				if choice ~= 1 then
					return
				end

				local new_recent = {}
				if history.recent_projects then
					for _, p in ipairs(history.recent_projects) do
						local norm = p:gsub('\\', '/'):gsub('/$', ''):lower()
						if norm ~= target_val then
							table.insert(new_recent, p)
						end
					end
					history.recent_projects = new_recent
				end

				local new_session = {}
				if history.session_projects then
					for _, p in ipairs(history.session_projects) do
						local norm = p:gsub('\\', '/'):gsub('/$', ''):lower()
						if norm ~= target_val then
							table.insert(new_session, p)
						end
					end
					history.session_projects = new_session
				end

				save_history_to_disk(history.get_recent_projects())

				actions.close(prompt_bufnr)
				vim.schedule(function()
					require('telescope').extensions.projects.projects({})
				end)
			end

			require('telescope').extensions.projects.projects({
				attach_mappings = function(_, map)
					map('i', '<C-r>', delete_project)
					map('n', '<C-r>', delete_project)
					return true
				end,
			})
		end, { desc = 'Telescope recent projects' })
	end,
}
