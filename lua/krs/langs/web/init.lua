-- ============================================================================
-- KRS WEB: Centralized Web Frontend Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Web frontend projects (HTML, CSS, Vue, Svelte, Astro) often use formatters like Prettier or Biome.
--   - If project formatter configs (.prettierrc*, biome.json*, .editorconfig) exist,
--     defer to those formatters and skip overriding buffer settings.
--   - If NO project formatter config exists, fallback 2-space defaults are applied.
-- ============================================================================

local M = {}

--- Formatter and tool configuration files for Web Frontend projects.
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
}

--- Fallback defaults for Web Frontend (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply Web Frontend fallback defaults if no formatter config or .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_project_config(buf, M.formatter_configs) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Web Frontend language configuration autocmds.
function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "html", "css", "scss", "less", "vue", "svelte", "astro" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
