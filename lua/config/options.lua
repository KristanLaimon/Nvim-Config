vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.number = true
vim.opt.cursorline = true
vim.opt.relativenumber = true
vim.opt.expandtab = false
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

if vim.fn.has("wsl") == 1 or vim.fn.has("unix") == 1 then
  vim.opt.shell = "bash"
elseif vim.fn.has("win32") == 1 then
  vim.opt.shell = "C:\\PROGRA~1\\Git\\bin\\bash.exe"
  vim.opt.shellcmdflag = "-c"
  vim.opt.shellxquote = ""
  vim.opt.shellquote = ""
end

-- Ensure PATH includes Node.js (installer exe, nvm, fnm, pnpm, volta, scoop, etc.) and CLI tools for GUI clients
local function setup_path_env()
  local is_win = vim.fn.has("win32") == 1
  local sep = is_win and ";" or ":"
  local current_path = vim.env.PATH or ""

  local candidate_paths = {}

  if is_win then
    candidate_paths = {
      -- fnm (Fast Node Manager)
      vim.fn.expand("$APPDATA/fnm/aliases/default"),
      -- nvm-windows
      vim.env.NVM_SYMLINK,
      vim.env.NVM_HOME,
      "C:\\Program Files\\nodejs",
      "C:\\Program Files (x86)\\nodejs",
      vim.fn.expand("$APPDATA/npm"),
      -- pnpm (Global / Node installs via pnpm)
      vim.env.PNPM_HOME,
      vim.fn.expand("$LOCALAPPDATA/pnpm"),
      vim.fn.expand("$APPDATA/pnpm"),
      -- Volta
      vim.env.VOLTA_HOME and (vim.env.VOLTA_HOME .. "\\bin"),
      vim.fn.expand("$LOCALAPPDATA/volta/bin"),
      vim.fn.expand("$USERPROFILE/.volta/bin"),
      -- Scoop & Chocolatey
      vim.fn.expand("$USERPROFILE/scoop/shims"),
      vim.fn.expand("$USERPROFILE/scoop/apps/nodejs/current"),
      vim.fn.expand("$USERPROFILE/scoop/apps/nodejs-lts/current"),
      "C:\\ProgramData\\chocolatey\\bin",
      -- Bun / Deno / Yarn
      vim.fn.expand("$USERPROFILE/.bun/bin"),
      vim.fn.expand("$USERPROFILE/.deno/bin"),
      vim.fn.expand("$LOCALAPPDATA/Yarn/bin"),
      -- Cargo / Go
      vim.fn.expand("$USERPROFILE/.cargo/bin"),
      vim.fn.expand("$USERPROFILE/go/bin"),
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
    if path and path ~= "" and vim.fn.isdirectory(path) == 1 then
      local normalized = is_win and path:gsub("/", "\\") or path
      if not current_path:find(normalized, 1, true) then
        current_path = normalized .. sep .. current_path
      end
    end
  end

  vim.env.PATH = current_path
end

setup_path_env()


