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
				tsgo = {
					-- nvim 0.11+ signature: (bufnr, on_dir). Must CALL on_dir; return value is ignored.
					root_dir = function(bufnr, on_dir)
						local root = vim.fs.root(bufnr, {
							"tsconfig.json",
							"jsconfig.json",
							"package.json",
							".krsnvim",
							".nvimkrs",
						})
						local home = vim.fs.normalize(vim.env.USERPROFILE or vim.env.HOME or ""):lower()
						if not root or vim.fs.normalize(root):lower() == home then
							on_dir(vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
						else
							on_dir(root)
						end
					end,
					-- Automatic Type Acquisition must stay OFF. In a project with no
					-- tsconfig.json, ATA downloads @types/* into
					-- %LOCALAPPDATA%/Microsoft/TypeScript/<ver> and injects them a few
					-- seconds after attach -- that is the "types were missing, then
					-- IntelliSense came back on its own" behaviour. It hides the
					-- "install type definitions" error and makes the Type Injector's
					-- enable/disable state meaningless.
					--
					-- "js/ts" is the section tsgo actually asks for over
					-- workspace/configuration (alongside typescript/javascript/editor).
					-- Neither `init_options.disableAutomaticTypeAcquisition` nor
					-- tsserver's `preferences.disableAutomaticTypingAcquisition` has any
					-- effect here -- both were verified inert against this binary.
					settings = {
						["js/ts"] = {
							disableAutomaticTypeAcquisition = true,
						},
					},
				},
				biome = {},
				eslint = {},
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
				html = {
					filetypes = { "html", "templ", "hbs" },
				},
				cssls = {
					settings = {
						css = { validate = true, lint = { unknownAtRules = "ignore" } },
						scss = { validate = true, lint = { unknownAtRules = "ignore" } },
						less = { validate = true },
					},
				},
				tailwindcss = {
					filetypes = {
						"html",
						"css",
						"scss",
						"javascript",
						"javascriptreact",
						"typescript",
						"typescriptreact",
						"svelte",
						"vue",
						"astro",
					},
					settings = {
						tailwindCSS = {
							experimental = {
								classRegex = {
									{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
									{ "cx\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
									{ "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
								},
							},
						},
					},
				},
				emmet_ls = {
					filetypes = {
						"html",
						"typescriptreact",
						"javascriptreact",
						"css",
						"sass",
						"scss",
						"less",
						"svelte",
						"vue",
						"astro",
					},
				},
				omnisharp = {
					cmd = { "omnisharp" },
					enable_roslyn_analyzers = true,
					organize_imports_on_format = true,
					enable_import_completion = true,
				},
				lemminx = {},
				dockerls = {},
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
								library = require("config.krs.type_injector").get_active_lua_libraries(),
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
			local has_blink, blink = pcall(require, "blink.cmp")

			-- 1. Initialize Mason
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"jsonls",
					"taplo",
					"yamlls",
					"biome",
					"eslint",
					"svelte",
					"astro",
					"html",
					"cssls",
					"tailwindcss",
					"emmet_ls",
					"omnisharp",
					"lemminx",
					"dockerls",
				},
				handlers = {
					function(server_name)
						if server_name == "vtsls" or server_name == "ts_ls" or server_name == "tsserver" then
							return
						end
						local config = opts.servers[server_name] or {}
						if has_blink then
							config.capabilities = blink.get_lsp_capabilities(config.capabilities)
						end
						vim.lsp.config(server_name, config)
						vim.lsp.enable(server_name)
					end,
				},
			})

			vim.diagnostic.config({
				virtual_text = {
					source = "if_many",
					prefix = "●",
				},
				underline = true,
				signs = true,
				severity_sort = true,
			})

			-- tsgo advertises `diagnosticProvider`, so nvim pulls and refreshes diagnostics
			-- natively. A hand-rolled fetch into a private namespace only froze whatever
			-- the server happened to know a few hundred ms after attach -- typically
			-- before node_modules was loaded -- and never refreshed it.

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
							-- ["prettierrc.json"] = get_schema_uri("json", "prettierrc.json"),
							[".eslintrc"] = get_schema_uri("json", "eslintrc.json"),
							["jsconfig.json"] = get_schema_uri("json", "jsconfig.json"),
							["babelrc.json"] = get_schema_uri("json", "babelrc.json"),
							["Turborepo"] = get_schema_uri("json", "turbo.json"),
						},
						extra = {
							{
								name = "prettierrc.json",
								description = "Prettier configuration schema",
								fileMatch = { "prettierrc.json", "prettier.config.json" },
								url = get_schema_uri("json", "prettierrc.json"),
							},
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

			-- Stop duplicate TS LSP servers so only tsgo runs
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client and (client.name == "vtsls" or client.name == "ts_ls" or client.name == "tsserver") then
						client:stop()
					end
				end,
			})

			for server, config in pairs(opts.servers) do
				if server ~= "vtsls" and server ~= "ts_ls" and server ~= "tsserver" then
					if config and config.enabled ~= false then
						if has_blink then
							config.capabilities = blink.get_lsp_capabilities(config.capabilities)
						end
						vim.lsp.config(server, config)
						vim.lsp.enable(server)
					end
				end
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
