local width_file = vim.fn.stdpath("state") .. "/neotree_width"

local function load_saved_width()
  local f = io.open(width_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local w = tonumber(content)
    if w and w >= 15 and w <= 150 then
      return w
    end
  end
  return 24
end

local saved_width = load_saved_width()

local function save_width(w)
  if type(w) == "number" and w >= 15 and w <= 150 and w ~= saved_width then
    saved_width = w
    local f = io.open(width_file, "w")
    if f then
      f:write(tostring(w))
      f:close()
    end
  end
end

local group = vim.api.nvim_create_augroup("NeoTreeWidthSaver", { clear = true })
vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    local windows = vim.v.event.windows
    if not windows or #windows == 0 then
      windows = vim.api.nvim_tabpage_list_wins(0)
    end
    for _, winid in ipairs(windows) do
      if vim.api.nvim_win_is_valid(winid) then
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "neo-tree" then
          local w = vim.api.nvim_win_get_width(winid)
          save_width(w)
        end
      end
    end
  end,
})

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
		width = function()
		  return saved_width
		end,
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
