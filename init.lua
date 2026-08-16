-- ============================================================================
-- KrsVim -- entry point.
-- ============================================================================
-- STARTUP ORDER (each step depends on the one before it)
--   1. config.options   Editor options, filetypes, shell, PATH repair.
--   2. config.keymaps   Every keybinding, grouped by domain.
--   3. config.lazy      Bootstraps lazy.nvim and imports lua/plugins/*.
--
-- WHERE THINGS LIVE
--   lua/config/    Editor bootstrap: options, keymaps, plugin manager.
--   lua/krs/       Shared internal libraries (core, git, launch, lsp).
--   lua/plugins/   One lazy.nvim spec per file, grouped by area.
--   lua/krsnvim/   The krsnvimscript automation library (its own public API).
--   tests/         Unit specs (`nvim -l tests/run.lua`) and integration specs.
--   docs/          Architecture and feature documentation.
--
-- See docs/architecture.md for the full picture.
-- ============================================================================

-- Byte-compilation cache: cuts startup roughly in half on Windows.
if vim.loader then
	vim.loader.enable()
end

require("config.options")
require("config.keymaps")
require("config.lazy")

-- Reload the configuration without restarting. Only `config.*` modules are
-- dropped from the cache; plugins keep their state, which is what makes this
-- fast enough to use while editing keymaps.
vim.api.nvim_create_user_command("ReloadConfig", function()
	for name, _ in pairs(package.loaded) do
		if name:match("^config") then
			package.loaded[name] = nil
		end
	end
	dofile(vim.env.MYVIMRC)
	vim.notify("Config reloaded", vim.log.levels.INFO)
end, {})

-- Run the test suite from inside the editor. The same specs run headlessly with
-- `nvim -l tests/run.lua`; see tests/run.lua for the runner itself.
vim.api.nvim_create_user_command("KrsTest", function(command)
	local root = vim.fn.stdpath("config")
	local runner = dofile(root .. "/tests/run.lua")
	runner.run(root, command.args ~= "" and command.args or nil)
end, { nargs = "?", desc = "Run the KRS unit test suite (optionally filtered by spec name)" })

-- If nvim is being run inside neovide wrapper
if vim.g.neovide then
	vim.g.neovide_window_blurred = true
	vim.g.neovide_transparency = 0.48
	vim.g.neovide_normal_opacity = 0.48
	-- vim.g.neovide_show_border = true
end
