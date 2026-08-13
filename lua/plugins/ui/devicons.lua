return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    opts = {
      -- enable default icons for unknown filetypes
      default = true,
      -- enable color icons
      color_icons = true,
      override_by_extension = {
        ["krsnvim"] = {
          icon = "🦊",
          color = "#e67e22",
          cterm_color = "166",
          name = "KrsNvim",
        },
      },
    },
    config = function(_, opts)
      local devicons = require("nvim-web-devicons")
      devicons.setup(opts)
      devicons.set_icon({
        krsnvim = {
          icon = "🦊",
          color = "#e67e22",
          cterm_color = "166",
          name = "KrsNvim",
        },
      })
    end,
  },
}
