return {
    'goolord/alpha-nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
        local alpha = require('alpha')
        local dashboard = require('alpha.themes.dashboard')

        dashboard.section.header.val = {
            [[                                                ]],
            [[            /\   /\                             ]],
            [[           ( ..   .. )      _  __ ____  ____    ]],
            [[            \  Y  /        | |/ /|  _ \/ ___|   ]],
            [[         /\_/\   /\_/\     | ' / | |_) \___ \   ]],
            [[        (  o o     o o)    | . \ |  _ < ___) |  ]],
            [[         \  ~   ~  /       |_|\_\|_| \_\____/   ]],
            [[          \___^___/                             ]],
            [[                                                ]],
        }

        dashboard.section.buttons.val = {
            dashboard.button('f', '  Find file', ':Telescope find_files<CR>'),
            dashboard.button('r', '  Recent files', ':Telescope oldfiles<CR>'),
            dashboard.button('p', '  Recent projects', ':Telescope projects<CR>'),
            dashboard.button('g', '  Live grep', ':Telescope live_grep<CR>'),
            dashboard.button('n', '  New file', ':ene <BAR> startinsert<CR>'),
            dashboard.button('c', '  Config', ':e $MYVIMRC<CR>'),
            dashboard.button('q', '  Quit', ':qa<CR>'),
        }

        dashboard.section.footer.val = ''

        alpha.setup(dashboard.opts)

        -- Closing the last real buffer shows the dashboard instead of quitting.
        vim.api.nvim_create_autocmd("BufDelete", {
            callback = function()
                vim.schedule(function()
                    local listed = vim.tbl_filter(function(b)
                        return vim.fn.buflisted(b) == 1 and vim.api.nvim_buf_get_name(b) ~= ""
                    end, vim.api.nvim_list_bufs())

                    if #listed == 0 and vim.bo.filetype ~= "alpha" then
                        vim.cmd("Alpha")
                    end
                end)
            end,
        })
    end
}
