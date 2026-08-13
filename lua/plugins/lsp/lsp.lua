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
	pattern = {
		[".*%.blade%.php"] = "blade",
	},
})

return {
	{
		-- Its own spec so `:Mason` exists on an empty nvim too. Without this, mason
		-- is only ever pulled in as an nvim-lspconfig dependency, and setup() (which
		-- registers the command) runs on BufReadPre — no file open, no :Mason.
		"williamboman/mason.nvim",
		cmd = "Mason",
		opts = {},
	},
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
				intelephense = {
					settings = {
						intelephense = {
							files = {
								maxSize = 1000000,
							},
							stubs = {
								"bcmath",
								"Core",
								"curl",
								"date",
								"hash",
								"json",
								"mbstring",
								"openssl",
								"pcre",
								"PDO",
								"Reflection",
								"SPL",
								"standard",
								"tokenizer",
								"zlib",
								"laravel",
								"phpunit",
							},
						},
					},
				},
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
					filetypes = { "html", "templ", "hbs", "php", "blade" },
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
						"php",
						"blade",
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
						"php",
						"blade",
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
				gopls = {},
				bashls = {
					filetypes = { "sh", "bash", "zsh", "csh", "ksh" },
				},
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
								library = require("plugins.krs.type_injector").get_active_lua_libraries(),
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
					"intelephense",
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
					"gopls",
					"bashls",
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
								fileMatch = { "prettierrc.json", "prettier.config.json", ".prettierrc.astro.json" },
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
			enabled = function()
				return vim.bo.filetype ~= "krsinputmodal" and vim.b.completion ~= false
			end,
			keymap = {
				preset = "default",
				["<CR>"] = { "accept", "fallback" },
				["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-@>"] = { "show", "show_documentation", "hide_documentation" },
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			completion = {
				menu = {
					-- Don't auto-pop inside a freshly inserted empty pair ("{}" from autopairs).
					-- Only auto-show is suppressed: <C-space> still opens the menu there,
					-- which is what `import { | }` needs.
					auto_show = function()
						local line = vim.api.nvim_get_current_line()
						local col = vim.api.nvim_win_get_cursor(0)[2]
						local before, after = line:sub(col, col), line:sub(col + 1, col + 1)
						local pairs_map = { ["{"] = "}", ["["] = "]", ["("] = ")" }
						return pairs_map[before] ~= after
					end,
				},
				documentation = { auto_show = false },
				trigger = {
					-- "{" and "[" open bracket-pair snippets on every keystroke otherwise
					show_on_blocked_trigger_characters = { " ", "\n", "\t", "{", "[", "(" },
				},
			},
			signature = {
				enabled = true,
				window = { border = "rounded" },
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
				-- Debug repl completes from the stopped frame only, never lsp/buffer words.
				per_filetype = { ["dap-repl"] = { "dap" } },
				providers = {
					dap = { name = "DAP", module = "krs.dap_repl_source", async = true },
				},
			},
			fuzzy = {
				implementation = "prefer_rust_with_warning",
				prebuilt_binaries = {
					download = true,
				},
				sorts = {
					-- always rank snippets (LSP kind 15) below real completions, regardless of fuzzy score
					function(a, b)
						local a_snip, b_snip = a.kind == 15, b.kind == 15
						if a_snip == b_snip then
							return nil
						end
						return b_snip
					end,
					"score",
					"sort_text",
				},
			},
		},
		opts_extend = { "sources.default" },
	},
}
