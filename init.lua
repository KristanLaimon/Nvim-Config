if vim.loader then
	vim.loader.enable()
end

require("config.options")
require("config.keybinds")
require("config.lazy")
pcall(function()
	require("config.krs.intellij_toolbar").setup()
end)

vim.api.nvim_create_user_command("ReloadConfig", function()
	for name, _ in pairs(package.loaded) do
		if name:match("^config") then
			package.loaded[name] = nil
		end
	end
	dofile(vim.env.MYVIMRC)
	vim.notify("Config reloaded", vim.log.levels.INFO)
end, {})
