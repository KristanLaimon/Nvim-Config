-- ============================================================================
-- KRS LANGS: Centralized Per-Language Configuration Manager
-- ============================================================================
-- WHAT IT DOES
--   1. Automatically imports and executes `setup()` for per-language submodules
--      under `lua/krs/langs/<lang>/init.lua`.
--   2. Provides `has_editorconfig(buf)` and `has_project_config(buf, config_files)`
--      helpers so per-language defaults apply only when no project-level
--      formatter configs (Prettier, Biome, ESLint, EditorConfig, Pint, etc.) exist.
-- ============================================================================

local M = {}

--- Helper to check if an `.editorconfig` file has applied settings to the buffer,
--- or if an `.editorconfig` file exists in the directory hierarchy of the buffer.
--- @param buf integer|nil Buffer handle (defaults to current).
--- @return boolean has_editorconfig
function M.has_editorconfig(buf)
	buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()

	-- Check Neovim buffer-local editorconfig flags
	if vim.b[buf].editorconfig ~= nil or vim.b[buf].editorconfig_applied then
		return true
	end

	-- Check if an .editorconfig file exists in the buffer's folder hierarchy
	local name = vim.api.nvim_buf_get_name(buf)
	if name and name ~= "" then
		local dir = vim.fs.dirname(name)
		if dir and dir ~= "" then
			local found = vim.fs.find(".editorconfig", { upward = true, path = dir })
			if found and #found > 0 then
				return true
			end
		end
	end

	return false
end

--- Helper to check whether a buffer belongs to a project with EditorConfig or any
--- specific formatter/tool configuration files (e.g. Prettier, Biome, ESLint, Deno, Pint).
--- @param buf integer|nil Buffer handle (defaults to current).
--- @param config_files table|nil Optional list of formatter/tool config filenames to look for.
--- @return boolean has_config
function M.has_project_config(buf, config_files)
	buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()

	if M.has_editorconfig(buf) then
		return true
	end

	if config_files and #config_files > 0 then
		local name = vim.api.nvim_buf_get_name(buf)
		if name and name ~= "" then
			local dir = vim.fs.dirname(name)
			if dir and dir ~= "" then
				local found = vim.fs.find(config_files, { upward = true, path = dir })
				if found and #found > 0 then
					return true
				end
			end
		end
	end

	return false
end

--- Registered per-language configuration submodules.
M.langs = {
	php = require("krs.langs.php"),
	typescript = require("krs.langs.typescript"),
	web = require("krs.langs.web"),
	csharp = require("krs.langs.csharp"),
	go = require("krs.langs.go"),
	python = require("krs.langs.python"),
	lua = require("krs.langs.lua"),
	bash = require("krs.langs.bash"),
	docker_proto = require("krs.langs.docker_proto"),
}

--- Initialize all per-language configuration submodules.
function M.setup()
	for _, lang in pairs(M.langs) do
		if type(lang) == "table" and type(lang.setup) == "function" then
			lang.setup()
		end
	end
end

return M
