return {
  "vuki656/package-info.nvim",
  dependencies = "MunifTanjim/nui.nvim",
  ft = "json",
  config = function()
    require("package-info").setup({
      autostart = false, -- Prevent automatic background execution of pnpm/yq shell commands on file open
      hide_up_to_date = true,
      hide_unstable_versions = true,
      -- Auto-detects via lockfile (bun.lock, pnpm-lock.yaml, etc); this is fallback
      package_manager = "bun",
    })

    local info = require("package-info")
    vim.keymap.set("n", "<leader>ns", info.show, { silent = true, desc = "Show package versions" })
    vim.keymap.set("n", "<leader>nc", info.hide, { silent = true, desc = "Hide package versions" })
    vim.keymap.set("n", "<leader>nu", info.update, { silent = true, desc = "Update package" })
    vim.keymap.set("n", "<leader>nd", info.delete, { silent = true, desc = "Delete package" })
    vim.keymap.set("n", "<leader>ni", info.install, { silent = true, desc = "Install new package" })
    vim.keymap.set("n", "<leader>np", info.change_version, { silent = true, desc = "Change package version" })
  end,
}
