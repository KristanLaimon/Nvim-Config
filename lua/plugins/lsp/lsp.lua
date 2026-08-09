-- MSBuild project/props files are XML; register them so lemminx (below)
-- attaches and gives IntelliSense in .csproj etc.
vim.filetype.add({
	extension = {
		csproj = "xml",
		fsproj = "xml",
		vbproj = "xml",
		props = "xml",
		targets = "xml",
	},
})

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
				editorconfig_ls = {},
				taplo = {},
				yamlls = {
					settings = {
						yaml = {
							schemaStore = {
								enable = false,
								url = "",
							},
							schemas = require("schemastore").yaml.schemas(),
						},
					},
				},
				jsonls = {},
				ts_ls = {},
				svelte = {
					on_attach = function(client, _)
						vim.api.nvim_create_autocmd("BufWritePost", {
							pattern = { "*.js", "*.ts" },
							callback = function(ctx)
								client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
							end,
						})
					end,
				},
				astro = {},
				html = {},
				cssls = {},
				tailwindcss = {},
				omnisharp = {
					cmd = { "omnisharp" },
					enable_roslyn_analyzers = true,
					organize_imports_on_format = true,
					enable_import_completion = true,
				},
				lemminx = {},
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
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"jsonls",
					"editorconfig_ls",
					"taplo",
					"yamlls",
					"ts_ls",
					"svelte",
					"astro",
					"html",
					"cssls",
					"tailwindcss",
					"omnisharp",
					"lemminx",
				},
			})

			vim.diagnostic.config({
				virtual_text = true,
				underline = true,
			})

			local function get_schema_uri(category, filename)
				local path = vim.fs.normalize(vim.fn.stdpath("config") .. "/schemas/" .. category .. "/" .. filename)
				return vim.uri_from_fname(path)
			end

			opts.servers.jsonls.settings = {
				json = {
					schemas = require("schemastore").json.schemas({
						select = {
							"tsconfig.json",
							"package.json",
							"prettierrc.json",
							".eslintrc",
							"jsconfig.json",
							"babelrc.json",
							"Turborepo",
							"biome.json",
						},
						replace = {
							["tsconfig.json"] = get_schema_uri("json", "tsconfig.json"),
							["package.json"] = get_schema_uri("json", "package.json"),
							["prettierrc.json"] = get_schema_uri("json", "prettierrc.json"),
							[".eslintrc"] = get_schema_uri("json", "eslintrc.json"),
							["jsconfig.json"] = get_schema_uri("json", "jsconfig.json"),
							["babelrc.json"] = get_schema_uri("json", "babelrc.json"),
							["Turborepo"] = get_schema_uri("json", "turbo.json"),
						},
						extra = {
							{
								name = "biome.json",
								description = "Biome configuration schema",
								fileMatch = { "biome.json", "biome.jsonc" },
								url = get_schema_uri("json", "biome.json"),
							},
						},
					}),
					validate = { enable = true },
				},
			}

			opts.servers.taplo.settings = {
				even_better_toml = {
					schema = {
						enabled = true,
						repository = false,
						associations = {
							["^bunfig\\.toml$"] = get_schema_uri("toml", "bunfig.json"),
						},
					},
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
