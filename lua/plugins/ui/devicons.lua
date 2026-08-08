return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    opts = {
      -- enable default icons for unknown filetypes
      default = true,
      -- enable color icons
      color_icons = true,
    },
    config = function(_, opts)
      require("nvim-web-devicons").setup(opts)
    end,
  },
}
