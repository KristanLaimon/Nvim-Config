return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  config = function()
    local config = require("nvim-treesitter")
    config.install({
      -- Core / Editor
      "lua",
      "vim",
      "vimdoc",
      "markdown",
      "markdown_inline",
      
      -- Frontend
      "typescript",
      "javascript",
      "tsx",
      "svelte",
      "astro",
      "html",
      "css",
      
      -- Backend / Data
      "go",
      "gomod",
      "gowork",
      "gosum",
      "json",
      "yaml",
      "toml",
    })
  end,
}
