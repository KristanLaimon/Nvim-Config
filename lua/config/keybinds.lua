-- GLOBAL CONFIG
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

-- VSCode Migration (Old habits never die)
    -- Comment or uncomment the current line in normal mode (without selecting anything) 
    vim.keymap.set('n', '<C-;>', 'gcc', { remap = true, desc = "Comment line" })

    -- Comment or uncomment the selection in visual mode (VsCode Style)
    vim.keymap.set('v', '<C-;>', 'gc', { remap = true, desc = "Comment selection" }) 


-- QOL Features
-- Copy the selection to the system clipboard with Ctrl + c in visual mode
vim.keymap.set('v', '<C-c>', '"+y', { noremap = true, desc = "Copy to clipboard" })

-- Movements across panels
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "Ir a la ventana izquierda" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "Ir a la ventana derecha" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "Ir a la ventana de abajo" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "Go to upper window" })
vim.keymap.set('n', '<C-;>', '<C-w>c', { desc = "Close window" })

-- Ver el mensaje del error con Espacio + i (Información)
vim.keymap.set('n', '<leader>k', vim.diagnostic.open_float, { desc = 'Ver info del error' })

-- Ir al error anterior (atrás) con Espacio + u
vim.keymap.set('n', '<leader>u', vim.diagnostic.goto_prev, { desc = 'Error anterior' })

-- Ir al siguiente error (enfrente) con Espacio + o
vim.keymap.set('n', '<leader>o', vim.diagnostic.goto_next, { desc = 'Siguiente error' })
    

-- =========== Plugin Specifics =================
-- Neo-tree
    -- Open/Close (Sidebar)
    vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { noremap = true, silent = true, desc = "Toggle Explorador" })
