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

-- Pin the sidebar width. neo-tree does not set 'winfixwidth' itself, so any
-- `wincmd =` (dap-ui opening its panels, plain splits) steals its width.
-- winfixwidth only blocks *shrinking* though: when a neighbour closes, nvim
-- hands the freed columns to the sidebar and it swallows the screen. So the
-- width is also re-asserted whenever a window closes.
local fix_group = vim.api.nvim_create_augroup("NeoTreeFixWidth", { clear = true })

local function pin_width()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
    if buf and vim.bo[buf].filetype == "neo-tree" then
      vim.wo[win].winfixwidth = true
      if vim.api.nvim_win_get_width(win) ~= saved_width then
        pcall(vim.api.nvim_win_set_width, win, saved_width)
      end
    end
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  group = fix_group,
  callback = pin_width,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = fix_group,
  callback = function()
    vim.schedule(pin_width)
  end,
})

-- Force other splits back to equal width when neo-tree opens/closes. `equalalways`
-- should already do this, but neo-tree's own resize event doesn't always fire it.
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWinLeave" }, {
  group = vim.api.nvim_create_augroup("NeoTreeEqualize", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].filetype == "neo-tree" then
      vim.schedule(function()
        pcall(vim.cmd, "wincmd =")
      end)
    end
  end,
})

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
    cmd = "Neotree",
    keys = {
      { "<C-S-Space>", ":Neotree toggle<CR>", desc = "Toggle Explorer" },
      { "<leader>e", ":Neotree toggle<CR>", desc = "Toggle Explorer" },
    },
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
	    -- Was true: while dap-ui tears its panels down neo-tree can momentarily be
	    -- the last window, close itself, and take the whole nvim session with it.
	    -- Smart-Quit (<C-q>) still handles quitting explicitly.
	    close_if_last_window = false,
	    window = {
		width = saved_width,
		mappings = {
		    ["r"] = "rename_with_modal",
		    ["m"] = "move_with_picker",
		    ["a"] = "add_file_with_modal",
		    ["A"] = "add_folder_with_modal",
		    ["<C-n>"] = "add_file_with_modal",
		    ["<C-S-n>"] = "add_folder_with_modal",
		    ["<C-S-N>"] = "add_folder_with_modal",
		    ["<C-/>"] = "search_respect_gitignore",
		    ["<C-_>"] = "search_respect_gitignore",
		    ["<C-S-/>"] = "search_all_files",
		    ["<C-?>"] = "search_all_files",
		    ["<C-S-CR>"] = "open_with_system_app",
		    ["<C-S-Enter>"] = "open_with_system_app",
		},
	    },
	    commands = {
		open_with_system_app = function(state)
		    local node = state.tree:get_node()
		    if node and node.path then
			require("plugins.krs.image_viewer").open_with_system_app(node.path)
		    end
		end,
		rename_with_modal = function(state)
		    local node = state.tree:get_node()
		    if not node or not node.path then
			return
		    end
		    local old_path = node.path
		    local old_name = node.name

		    require("plugins.krs.input_modal").open({
			label = "Rename (" .. old_name .. ")",
			default_value = old_name,
			relative = "editor",
			callback = function(ok, new_name)
			    if not ok or not new_name or new_name == "" or new_name == old_name then
				return
			    end
			    local parent_dir = vim.fn.fnamemodify(old_path, ":h")
			    local new_path = parent_dir .. "/" .. new_name

			    local success, err = os.rename(old_path, new_path)
			    if success then
				vim.notify("Renamed: " .. old_name .. " ➜ " .. new_name, vim.log.levels.INFO, { title = "Neo-tree" })
				pcall(function()
				    require("neo-tree.sources.manager").refresh("filesystem")
				end)
			    else
				vim.notify("Error renaming: " .. tostring(err), vim.log.levels.ERROR, { title = "Neo-tree" })
			    end
			end,
		    })
		end,
		move_with_picker = function(state)
		    local node = state.tree:get_node()
		    if not node or not node.path then
			return
		    end
		    require("plugins.krs.file_explorer").open_move_picker({
			source_path = node.path,
			root_dir = vim.fn.getcwd(),
		    })
		end,
		add_file_with_modal = function(state)
		    local node = state.tree:get_node()
		    if not node then
			return
		    end
		    local parent_dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")

		    require("plugins.krs.input_modal").open({
			label = "New File",
			default_value = "",
			relative = "editor",
			callback = function(ok, new_name)
			    if not ok or not new_name or new_name == "" then
				return
			    end
			    local clean_name = new_name:gsub("[/\\]+$", "")
			    if clean_name == "" then
				return
			    end
			    local target_path = parent_dir .. "/" .. clean_name
			    local target_parent = vim.fn.fnamemodify(target_path, ":h")
			    if vim.fn.isdirectory(target_parent) == 0 then
				vim.fn.mkdir(target_parent, "p")
			    end
			    local f = io.open(target_path, "w")
			    if f then
				f:close()
				vim.cmd("edit " .. vim.fn.fnameescape(target_path))
				vim.notify("Created file: " .. clean_name, vim.log.levels.INFO, { title = "Neo-tree" })
			    else
				vim.notify("Failed to create file: " .. clean_name, vim.log.levels.ERROR, { title = "Neo-tree" })
			    end
			    pcall(function()
				require("neo-tree.sources.manager").refresh("filesystem")
			    end)
			end,
		    })
		end,
		add_folder_with_modal = function(state)
		    local node = state.tree:get_node()
		    if not node then
			return
		    end
		    local parent_dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")

		    require("plugins.krs.input_modal").open({
			label = "New Folder",
			default_value = "",
			relative = "editor",
			callback = function(ok, new_name)
			    if not ok or not new_name or new_name == "" then
				return
			    end
			    local clean_name = new_name:gsub("[/\\]+$", "")
			    if clean_name == "" then
				return
			    end
			    local target_path = parent_dir .. "/" .. clean_name
			    vim.fn.mkdir(target_path, "p")
			    vim.notify("Created folder: " .. clean_name, vim.log.levels.INFO, { title = "Neo-tree" })
			    pcall(function()
				require("neo-tree.sources.manager").refresh("filesystem")
			    end)
			end,
		    })
		end,
		add_with_modal = function(state)
		    -- Fallback alias
		    local node = state.tree:get_node()
		    if not node then
			return
		    end
		    local parent_dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")

		    require("plugins.krs.input_modal").open({
			label = "New File / Folder",
			default_value = "",
			relative = "editor",
			callback = function(ok, new_name)
			    if not ok or not new_name or new_name == "" then
				return
			    end
			    local target_path = parent_dir .. "/" .. new_name
			    local is_dir = new_name:sub(-1) == "/" or new_name:sub(-1) == "\\"

			    if is_dir then
				vim.fn.mkdir(target_path, "p")
				vim.notify("Created folder: " .. new_name, vim.log.levels.INFO, { title = "Neo-tree" })
			    else
				local target_parent = vim.fn.fnamemodify(target_path, ":h")
				if vim.fn.isdirectory(target_parent) == 0 then
				    vim.fn.mkdir(target_parent, "p")
				end
				local f = io.open(target_path, "w")
				if f then
				    f:close()
				    vim.cmd("edit " .. vim.fn.fnameescape(target_path))
				    vim.notify("Created file: " .. new_name, vim.log.levels.INFO, { title = "Neo-tree" })
				end
			    end
			    pcall(function()
				require("neo-tree.sources.manager").refresh("filesystem")
			    end)
			end,
		    })
		end,
		search_respect_gitignore = function()
		    if _G.FindFilesGitignore then
			_G.FindFilesGitignore()
		    else
			require("telescope.builtin").find_files({ no_ignore = false })
		    end
		end,
		search_all_files = function()
		    if _G.FindFilesNoIgnore then
			_G.FindFilesNoIgnore()
		    else
			require("telescope.builtin").find_files({ no_ignore = true, hidden = true })
		    end
		end,

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
		    hide_gitignored = false,
		},
	    },
	}
    end
  },



  {
    "Crysthamus/nvim-file-operations",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-neo-tree/neo-tree.nvim",
    },
    config = function()
      require("nvim-file-operations").setup()
    end,
  },
  {
    "s1n7ax/nvim-window-picker",
    version = "2.*",
    lazy = true,
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

