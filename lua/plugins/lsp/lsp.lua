return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		cmd = { "LspInfo", "LspInstall", "LspStart" },
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
								library = {
									vim.env.VIMRUNTIME,
								},
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

			local has_blink, blink = pcall(require, "blink.cmp")
			for server, config in pairs(opts.servers) do
				if has_blink then
					config.capabilities = blink.get_lsp_capabilities(config.capabilities)
				end
				vim.lsp.config(server, config)
				vim.lsp.enable(server)
			end
		end,
	},
	{
		"saghen/blink.cmp",
		event = { "BufReadPre", "BufNewFile", "InsertEnter" },
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
			signature = {
				enabled = true,
				window = { border = "rounded" },
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

