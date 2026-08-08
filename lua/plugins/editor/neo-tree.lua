return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "antosha417/nvim-lsp-file-operations",
      "folke/snacks.nvim"
    },
    config = function ()
	vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { noremap = true, silent = true, desc = "Toggle Explorer" })
	require("neo-tree").setup {
	    window = {
		width = 24,
		mappings = {
		    ["<C-n>"] = "add",
		    ["<C-S-n>"] = "add_directory",
		},
	    },
	    filesystem = {
		bind_to_cwd = true,
		follow_current_file = {
		    enabled = true,
		    leave_dirs_open = false,
		},
		use_libuv_file_watcher = true,
		filtered_items = {
		    visible = true,
		    hide_dotfiles = false,
		    hide_gitignored = false
		}
	    }
	}

    end
  },
  {
    "Crysthamus/nvim-file-operations",
    -- branch = "compat" -- if you are on Neovim <= 0.10
    dependencies = {
      "nvim-neo-tree/neo-tree.nvim", -- makes sure that this loads after Neo-tree.
    },
    config = function()
      require("nvim-file-operations").setup()
    end,
  },
  {
    "s1n7ax/nvim-window-picker",
    version = "2.*",
    config = function()
      require("window-picker").setup({
        filter_rules = {
          include_current_win = false,
          autoselect_one = true,
          bo = {
            filetype = { "neo-tree", "neo-tree-popup", "notify" },
            buftype = { "terminal", "quickfix" },
          },
        },
      })
    end,
  },
}
