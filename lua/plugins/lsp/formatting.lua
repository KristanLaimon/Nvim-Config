return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre", "BufNewFile" },
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
				astro = { "prettierd", "prettier", "biome", stop_after_first = true },
				dockerfile = { "dockerfmt" },
			},
			formatters = {
				prettier = {
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
