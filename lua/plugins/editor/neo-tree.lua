local width_file = vim.fn.stdpath("state") .. "/neotree_width"

local function load_saved_width()
  local f = io.open(width_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local w = tonumber(content)
    if w and w >= 18 and w <= 60 then
      return w
    end
  end
  return 30
end

local saved_width = load_saved_width()

local function save_width(w)
  local max_allowed = math.min(60, math.floor((vim.o.columns or 80) * 0.45))
  if type(w) == "number" and w >= 18 and w <= max_allowed and w ~= saved_width then
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
    local wins = vim.api.nvim_tabpage_list_wins(0)
    -- Only save sidebar width if there are multiple windows in the tabpage
    if #wins <= 1 then
      return
    end
    for _, winid in ipairs(wins) do
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
	    close_if_last_window = true,
	    window = {
		width = saved_width,
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

	function _G.Neotree_Smart_Quit(force)
		if vim.bo.filetype == "neo-tree" then
			local code_win = nil
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local buf = vim.api.nvim_win_get_buf(win)
				local ft = vim.bo[buf].filetype
				local bt = vim.bo[buf].buftype
				if ft ~= "neo-tree" and bt == "" then
					code_win = win
					break
				end
			end

			if code_win then
				vim.api.nvim_set_current_win(code_win)
				local cmd = force and "bdelete!" or "bdelete"
				pcall(vim.cmd, cmd)
			else
				vim.cmd(force and "qall!" or "qall")
			end
		else
			local cmd = force and "bdelete!" or "bdelete"
			pcall(vim.cmd, cmd)
		end
	end

	vim.cmd([[
		cnoreabbrev <expr> q (getcmdtype() == ':' && getcmdline() ==# 'q' && &filetype ==# 'neo-tree') ? 'lua _G.Neotree_Smart_Quit(false)' : 'q'
		cnoreabbrev <expr> q! (getcmdtype() == ':' && getcmdline() ==# 'q!' && &filetype ==# 'neo-tree') ? 'lua _G.Neotree_Smart_Quit(true)' : 'q!'
	]])

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
