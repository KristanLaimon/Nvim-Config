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
				-- biome only formats the frontmatter/script block of these, never the
				-- template markup -- prefer prettier when configured, else fall back
				-- to biome so frontmatter still gets formatted
				svelte = { "prettierd", "prettier", "biome", stop_after_first = true },
				-- biome doesn't format .astro at all. prettierd can't take the
				-- --plugin flag astro needs, so plain prettier only here.
				astro = { "prettier" },
				dockerfile = { "dockerfmt" },
			},
			formatters = {
				prettier = {
					-- astro always uses prettier (no rc file needed, plugin below);
					-- everything else only if the project opted into prettier via rc file
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
							-- separate config name so a project's .prettierrc.astro.json
							-- doesn't also flip ts/js/css/etc onto prettier (their
							-- condition only looks for the standard .prettierrc names)
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
				-- biome's LSP attaches to astro/svelte too, but only formats the
				-- frontmatter -- its full-document edit fights astro-ls/svelteserver.
				-- conform's biome formatter (above) already covers the frontmatter,
				-- so drop the LSP client here to avoid double-formatting/conflicts.
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
