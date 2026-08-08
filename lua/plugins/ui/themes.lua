local function enable_transparency()
    if vim.g.neovide then
        return
    end
    vim.api.nvim_set_hl(0, "Normal", { bg = "#1b1b1d" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "#1b1b1d" })
end

return {
    {
        "doki-theme/doki-theme-vim",
        lazy = false,    -- Ensures the theme loads immediately on startup
        config = function()
            -- The Doki Theme plugin uses lowercase names for characters.
            -- If 'rei' throws an error, you can find the exact name by typing `:colorscheme ` in Neovim and pressing <Tab>.
            vim.cmd.colorscheme "rei"
            enable_transparency()
        end
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        opts = {
            -- 'auto' inherits the palette from the active colorscheme
            theme = "auto",
        }
    },
}
