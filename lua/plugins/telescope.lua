return {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', },
    config = function()
	local builtin = require('telescope.builtin')
	vim.keymap.set('n', '<C-k>', builtin.find_files, { desc = 'Telescope find files' })
	vim.keymap.set('i', '<C-k>', builtin.find_files, { desc = 'Telescope find files' })
	vim.keymap.set('n', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })
	vim.keymap.set('i', '<C-f>', builtin.live_grep, { desc = 'Telescope live grep' })

	-- vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
	vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
    end
}


