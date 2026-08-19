-- ============================================================================
-- KRS TS: Centralized TypeScript / JavaScript Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   JavaScript/TypeScript projects often rely on specialized formatters like Prettier,
--   Biome, ESLint, or Deno.
--   - If project formatter config files (.prettierrc*, biome.json*, eslint.config*, deno.json*, .editorconfig)
--     exist, we defer to those formatters and skip overriding buffer settings.
--   - If NO project formatter config exists, fallback 2-space defaults are applied.
-- ============================================================================

local M = {}

--- Formatter and tool configuration files that indicate a project-managed code style.
M.formatter_configs = {
	".prettierrc",
	".prettierrc.json",
	".prettierrc.yml",
	".prettierrc.yaml",
	".prettierrc.json5",
	".prettierrc.js",
	".prettierrc.cjs",
	".prettierrc.mjs",
	"prettier.config.js",
	"prettier.config.cjs",
	"prettier.config.mjs",
	"biome.json",
	"biome.jsonc",
	"deno.json",
	"deno.jsonc",
	"eslint.config.js",
	"eslint.config.mjs",
	"eslint.config.cjs",
	".eslintrc",
	".eslintrc.json",
	".eslintrc.js",
}

--- Fallback defaults for TypeScript / JavaScript (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply TypeScript / JavaScript fallback defaults if no formatter config or .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_project_config(buf, M.formatter_configs) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize TypeScript language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "typescript", "javascript", "typescriptreact", "javascriptreact", "json", "jsonc" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
