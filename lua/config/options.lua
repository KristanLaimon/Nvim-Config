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


