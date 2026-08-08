return {
  {
    "NeogitOrg/neogit",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      local neogit = require("neogit")
      local width = 60

      neogit.setup({
        kind = "vsplit",
        graph_style = "ascii",
        integrations = {
          diffview = true,
          telescope = true,
        },
        mappings = {
          status = {
            ["<cr>"] = "VSplitOpen",
            ["d"] = "PeekFile",
          },
        },
      })

      -- Neogit's vsplit opens on splitright side; force it hard right + fixed width.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "NeogitStatus",
        callback = function()
          vim.cmd("wincmd L")
          vim.cmd("vertical resize " .. width)
        end,
      })

      local function find_neogit_win()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "NeogitStatus" then
            return win
          end
        end
        return nil
      end

      local function toggle_neogit()
        local win = find_neogit_win()
        if win then
          vim.api.nvim_win_close(win, true)
        else
          neogit.open()
        end
      end

      vim.keymap.set("n", "<C-S-g>", toggle_neogit, { noremap = true, silent = true, desc = "Toggle Git Sidebar" })
    end,
  },
}
