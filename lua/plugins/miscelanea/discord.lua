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
