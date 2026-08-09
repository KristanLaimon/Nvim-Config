return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre", "BufNewFile" },
		cmd = { "ConformInfo" },
		opts = {
			formatters_by_ft = {
				go = { "goimports", "gofumpt" },
				lua = { "stylua" },
				json = { "prettierd", "prettier", stop_after_first = true },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },
				css = { "prettierd", "prettier", stop_after_first = true },
				html = { "prettierd", "prettier", stop_after_first = true },
				svelte = { "prettierd", "prettier", stop_after_first = true },
				astro = { "prettierd", "prettier", stop_after_first = true },
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

