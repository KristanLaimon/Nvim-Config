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
					condition = function(self, ctx)
						return vim.fn.executable("pint") == 1
							or vim.fs.find({ "vendor/bin/pint", "vendor/bin/pint.bat" }, { path = ctx.filename, upward = true })[1] ~= nil
					end,
				},
				php_cs_fixer = {
					condition = function(self, ctx)
						return vim.fn.executable("php-cs-fixer") == 1
							or vim.fs.find({ "vendor/bin/php-cs-fixer", "vendor/bin/php-cs-fixer.bat" }, { path = ctx.filename, upward = true })[1] ~= nil
					end,
				},
				prettier = {
					condition = function(self, ctx)
						return ctx.filetype == "astro"
							or vim.fs.find({
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
							}, { path = ctx.filename, upward = true })[1] ~= nil
					end,
					args = function(self, ctx)
						local args = { "--stdin-filepath", "$FILENAME" }
						if ctx.filetype == "astro" then
							vim.list_extend(args, { "--plugin", "prettier-plugin-astro" })
							local cfg = vim.fs.find(
								{ ".prettierrc.astro.json" },
								{ path = ctx.filename, upward = true }
							)[1]
							if cfg then
								vim.list_extend(args, { "--config", cfg })
							end
						end
						return args
					end,
				},
				prettierd = {
					condition = function(self, ctx)
						return vim.fs.find({
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
							}, { path = ctx.filename, upward = true })[1] ~= nil
					end,
				},
			},
			format_on_save = {
				timeout_ms = 1000,
				lsp_fallback = true,
			},
			default_format_opts = {
				lsp_format = "fallback",
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
