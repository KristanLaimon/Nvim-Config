-- ============================================================================
-- PLUGINS: conform.nvim -- formatting on save, with the project's own tools.
-- ============================================================================
-- THE RULE THIS FILE FOLLOWS
--   A formatter only runs when the PROJECT asks for it. prettier and prettierd
--   are skipped unless a prettier config file exists somewhere above the file;
--   pint and php-cs-fixer need the binary or a `vendor/bin` copy. Otherwise
--   opening someone else's repository would silently reformat it on save.
--
--   `stop_after_first` means the list is a preference order, not a pipeline:
--   prettierd (daemon, fast) then prettier then biome.
--
-- WHERE TO CHANGE THINGS
--   formatters_by_ft   Which tool formats which filetype.
--   detection          The config files that mark a project as prettier-managed.
--   format_on_save     Timeout and LSP fallback.
--
-- MANUAL FORMAT
--   <leader>ff (see lua/config/keymaps/lsp.lua).
-- ============================================================================

--- Files that mark a project as prettier-formatted. Checked upward from the file
--- being saved, so a monorepo root config counts.
local PRETTIER_CONFIG_FILES = {
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
}

--- True when `filename` sits inside a prettier-managed project.
--- @param filename string Path of the file being formatted.
--- @return boolean
local function has_prettier_config(filename)
	return vim.fs.find(PRETTIER_CONFIG_FILES, { path = filename, upward = true })[1] ~= nil
end

--- True when a PHP tool is available: on PATH, or vendored by the project.
--- @param executable string Binary name.
--- @param filename string Path of the file being formatted.
--- @return boolean
local function has_php_tool(executable, filename)
	if vim.fn.executable(executable) == 1 then
		return true
	end
	return vim.fs.find(
		{ "vendor/bin/" .. executable, "vendor/bin/" .. executable .. ".bat" },
		{ path = filename, upward = true }
	)[1] ~= nil
end

return {
	{
		"stevearc/conform.nvim",
		event = { "BufReadPre", "BufNewFile" },
		cmd = { "ConformInfo" },
		opts = {
			formatters_by_ft = {
				go = { "goimports", "gofumpt" },
				lua = { "stylua" },
				json = { "prettierd", "prettier", "biome", stop_after_first = true },
				javascript = { "prettierd", "prettier", "biome", stop_after_first = true },
				typescript = { "prettierd", "prettier", "biome", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", "biome", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", "biome", stop_after_first = true },
				css = { "prettierd", "prettier", "biome", stop_after_first = true },
				html = { "prettierd", "prettier", "biome", stop_after_first = true },
				svelte = { "prettierd", "prettier", "biome", stop_after_first = true },
				astro = { "prettier" },
				dockerfile = { "dockerfmt" },
				php = { "pint", "php_cs_fixer", stop_after_first = true },
				blade = { "blade-formatter", "pint", stop_after_first = true },
				sh = { "beautysh" },
				bash = { "beautysh" },
				zsh = { "beautysh" },
				csh = { "beautysh" },
				ksh = { "beautysh" },
			},
			formatters = {
				pint = {
					condition = function(_, ctx)
						return has_php_tool("pint", ctx.filename)
					end,
				},
				php_cs_fixer = {
					condition = function(_, ctx)
						return has_php_tool("php-cs-fixer", ctx.filename)
					end,
				},
				prettier = {
					-- Astro is the exception: its plugin has to be passed explicitly, so
					-- prettier runs for .astro files even without a project config.
					condition = function(_, ctx)
						return ctx.filetype == "astro" or has_prettier_config(ctx.filename)
					end,
					args = function(_, ctx)
						local args = { "--stdin-filepath", "$FILENAME" }
						if ctx.filetype == "astro" then
							vim.list_extend(args, { "--plugin", "prettier-plugin-astro" })
							local config = vim.fs.find({ ".prettierrc.astro.json" }, { path = ctx.filename, upward = true })[1]
							if config then
								vim.list_extend(args, { "--config", config })
							end
						end
						return args
					end,
				},
				prettierd = {
					condition = function(_, ctx)
						return has_prettier_config(ctx.filename)
					end,
				},
			},
			format_on_save = {
				timeout_ms = 1000,
				lsp_fallback = true,
			},
			default_format_opts = {
				lsp_format = "fallback",
				-- biome mangles Astro and Svelte components; let their own LSP do it.
				filter = function(client)
					return not (
						client.name == "biome"
						and vim.tbl_contains({ "astro", "svelte" }, vim.bo.filetype)
					)
				end,
			},
		},
	},
	{
		"zapling/mason-conform.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "williamboman/mason.nvim", "stevearc/conform.nvim" },
		config = function()
			require("mason-conform").setup()
		end,
	},
}
