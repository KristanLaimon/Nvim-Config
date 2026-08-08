return {
    'ahmedkhalf/project.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('project_nvim').setup({
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

        vim.keymap.set('n', '<C-S-r>', function()
            local history = require('project_nvim.utils.history')
            local tstate = require('telescope.actions.state')

            local function delete_project(prompt_bufnr)
                local selected = tstate.get_selected_entry(prompt_bufnr)
                if selected == nil then
                    return
                end
                local choice = vim.fn.confirm("Delete '" .. selected.value .. "' from project list?", "&Yes\n&No", 2)
                if choice == 1 then
                    history.delete_project(selected)
                    require('telescope.actions').close(prompt_bufnr)
                    vim.schedule(function()
                        require('telescope').extensions.projects.projects({})
                    end)
                end
            end

            require('telescope').extensions.projects.projects({
                attach_mappings = function(_, map)
                    map('i', '<C-r>', delete_project)
                    map('n', '<C-r>', delete_project)
                    return true
                end,
            })
        end, { desc = 'Telescope recent projects' })
    end
}
