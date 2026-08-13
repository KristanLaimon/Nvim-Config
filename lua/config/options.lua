vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Filetype registration for krsnvim scripts (*.krsnvim)
vim.filetype.add({
  extension = {
    krsnvim = "krsnvim",
  },
})

-- Under the hood, krsnvim scripts use Lua syntax & Treesitter parser
pcall(function()
  vim.treesitter.language.register("lua", "krsnvim")
end)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "krsnvim",
  callback = function()
    vim.bo.syntax = "lua"
  end,
})

vim.opt.number = true
vim.opt.cursorline = true
vim.opt.relativenumber = true
vim.opt.expandtab = false
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.showmode = false -- Hide native mode text (-- INSERT --) from bottom cmdline
vim.opt.cmdheight = 0 -- Remove dead space bottom command line row when idle (height = 0)
vim.opt.laststatus = 3 -- Ensure single global statusline at the bottom

-- Enforce cmdheight = 0 on VimEnter to prevent third-party plugins from restoring default cmdheight=1
vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
  callback = function()
    vim.opt.cmdheight = 0
  end,
})

-- Neovide / GUI window padding settings (removes 15px blank padding below status bar and window edges)
if vim.g.neovide then
  vim.g.neovide_padding_top = 0
  vim.g.neovide_padding_bottom = 0
  vim.g.neovide_padding_right = 0
  vim.g.neovide_padding_left = 0
end

-- Unicode & UTF-8 Encoding
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- Performance & Clipboard Optimizations
vim.opt.autoread = true        -- Automatically reload files modified externally
vim.opt.clipboard = "unnamedplus" -- Use system clipboard by default
vim.opt.updatetime = 250       -- Faster CursorHold and diagnostic updates
vim.opt.timeoutlen = 300       -- Snappier keybindings completion
vim.opt.redrawtime = 1500      -- Prevent redraw freeze on huge files
vim.opt.synmaxcol = 300        -- Limit syntax highlight column length for speed
vim.opt.swapfile = false       -- Disable swapfile I/O overhead
vim.opt.writebackup = false    -- Disable backup file creation
vim.opt.undofile = true        -- Save undo history to file efficiently


if vim.fn.has("wsl") == 1 or vim.fn.has("unix") == 1 then
  vim.opt.shell = "bash"
elseif vim.fn.has("win32") == 1 then
  vim.opt.shell = "C:\\PROGRA~1\\Git\\bin\\bash.exe"
  vim.opt.shellcmdflag = "-c"
  vim.opt.shellxquote = ""
  vim.opt.shellquote = ""
end

-- Fast PATH environment configuration (cached & using libuv for zero startup overhead)
local function setup_path_env()
  if vim.g._path_setup_done then
    return
  end
  vim.g._path_setup_done = true

  local is_win = vim.fn.has("win32") == 1
  local sep = is_win and ";" or ":"
  local current_path = vim.env.PATH or ""

  local appdata = vim.env.APPDATA or ""
  local localappdata = vim.env.LOCALAPPDATA or ""
  local userprofile = vim.env.USERPROFILE or ""
  local uv = vim.uv or vim.loop

  local function is_dir(path)
    if not path or path == "" then return false end
    local stat = uv.fs_stat(path)
    return stat and stat.type == "directory" or false
  end

  local candidate_paths = {}

  if is_win then
    candidate_paths = {
      appdata .. "\\fnm\\aliases\\default",
      vim.env.NVM_SYMLINK,
      vim.env.NVM_HOME,
      "C:\\Program Files\\nodejs",
      "C:\\Program Files (x86)\\nodejs",
      appdata .. "\\npm",
      vim.env.PNPM_HOME,
      localappdata .. "\\pnpm",
      appdata .. "\\pnpm",
      vim.env.VOLTA_HOME and (vim.env.VOLTA_HOME .. "\\bin"),
      localappdata .. "\\volta\\bin",
      userprofile .. "\\.volta\\bin",
      userprofile .. "\\scoop\\shims",
      userprofile .. "\\scoop\\apps\\nodejs\\current",
      userprofile .. "\\scoop\\apps\\nodejs-lts\\current",
      "C:\\ProgramData\\chocolatey\\bin",
      userprofile .. "\\.bun\\bin",
      userprofile .. "\\.deno\\bin",
      localappdata .. "\\Yarn\\bin",
      userprofile .. "\\.cargo\\bin",
      userprofile .. "\\go\\bin",
    }
  else
    local home = vim.fn.expand("~")
    candidate_paths = {
      "/opt/homebrew/bin",
      "/usr/local/bin",
      home .. "/.local/share/fnm/current/bin",
      home .. "/.nvm/current/bin",
      home .. "/.local/share/pnpm",
      home .. "/.volta/bin",
      home .. "/.local/share/mise/shims",
      home .. "/.asdf/shims",
      home .. "/.bun/bin",
      home .. "/.deno/bin",
      home .. "/.cargo/bin",
      home .. "/go/bin",
      home .. "/.local/bin",
    }
  end

  for _, path in ipairs(candidate_paths) do
    if is_dir(path) then
      local normalized = is_win and path:gsub("/", "\\") or path
      if not current_path:find(normalized, 1, true) then
        current_path = normalized .. sep .. current_path
      end
    end
  end

  vim.env.PATH = current_path
end

setup_path_env()

-- GUI & Font configuration with persistence (KRS Plugins are loaded via Lazy)
