return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"b0o/schemastore.nvim",
		},
		opts = {
			servers = {
				jsonls = {},
				lua_ls = {
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},

							diagnostics = {
								globals = { "vim" },
							},

							workspace = {
								checkThirdParty = false,
								library = vim.api.nvim_get_runtime_file("", true),
							},

							completion = {
								callSnippet = "Replace",
							},

							telemetry = {
								enable = false,
							},

							format = {
								enable = true,
								defaultConfig = {
									indent_style = "tab",
									indent_size = "2",
								},
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			-- 1. Initialize Mason
			require("mason").setup()
			require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "jsonls" } })

			vim.diagnostic.config({
				virtual_text = true,
				underline = true,
			})

			opts.servers.jsonls.settings = {
				json = {
					schemas = require("schemastore").json.schemas(),
					validate = { enable = true },
				},
			}

			for server, config in pairs(opts.servers) do
				config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
				vim.lsp.config(server, config)
				vim.lsp.enable(server)
			end
		end,
	},
	{
		"saghen/blink.cmp",
		dependencies = { "rafamadriz/friendly-snippets" },
		version = "*",
		opts = {
			keymap = {
				preset = "default",
				["<CR>"] = { "accept", "fallback" },
				["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-@>"] = { "show", "show_documentation", "hide_documentation" },
			},
			appearance = { nerd_font_variant = "mono" },
			completion = {
				menu = { auto_show = true },
				documentation = { auto_show = false },
			},
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			fuzzy = {
				implementation = "prefer_rust_with_warning",
				prebuilt_binaries = {
					download = true,
				},
			},
		},
		opts_extend = { "sources.default" },
	},
}
