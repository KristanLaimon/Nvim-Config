-- ============================================================================
-- PLUGIN: cord.nvim -- Discord rich presence.
-- ============================================================================
-- Shows what you are editing on your Discord profile: file, repository and
-- elapsed time, idle after five minutes. Purely cosmetic; toggle it at runtime
-- with `:Cord toggle` (also in the command palette under "Discord").
-- ============================================================================

return {
  "vyfor/cord.nvim",
  build = ":Cord update",
  event = "VeryLazy",
  opts = {
    usercmds = true,
    timer = {
      enable = true,
    },
    editor = {
      client = "neovim",
      tooltip = "Neovim",
    },
    display = {
      theme = "minecraft",
      flavor = "dark",
      show_time = true,
      show_repository = true,
    },
    idle = {
      enable = true,
      show_status = true,
      timeout = 300000,
    },
  },
}
