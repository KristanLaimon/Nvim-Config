return {
    'ahmedkhalf/project.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('project_nvim').setup({
            manual_gc = false,
        })
        require('telescope').load_extension('projects')

        vim.keymap.set('n', '<C-S-r>', function()
            require('telescope').extensions.projects.projects({})
        end, { desc = 'Telescope recent projects' })
    end
}
