-- ============================================================================
-- PLUGIN: nvim-web-devicons -- filetype icons for every list in the editor.
-- ============================================================================
-- Loaded eagerly because neo-tree, telescope, the bufferline and the dashboard
-- all ask for icons during startup.
--
-- The `.krsnvim` icon is registered three ways (extension, direct, filetype),
-- because each consumer looks it up differently.
-- ============================================================================

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
        ["proto"] = {
          icon = "",
          color = "#4285f4",
          cterm_color = "69",
          name = "Proto",
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
        proto = {
          icon = "",
          color = "#4285f4",
          cterm_color = "69",
          name = "Proto",
        },
      })
      devicons.set_icon_by_filetype({
        krsnvim = "krsnvim",
        proto = "proto",
      })
    end,
  },
}
